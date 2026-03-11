defmodule MetricFlow.DataSync.SyncWorker do
  @moduledoc """
  Oban worker that executes data sync operations for a single integration.

  Receives integration_id, user_id, and sync_job_id in Oban job args. Updates
  SyncJob status to running, retrieves integration tokens, delegates to the
  appropriate DataProvider based on the integration's provider field, persists
  metrics via MetricFlow.Metrics, creates a SyncHistory record with the sync
  outcome, and updates SyncJob status to completed or failed. Handles token
  refresh when tokens are expired.

  Enqueued by DataSync.Scheduler for daily runs, or directly via LiveView for
  manual sync triggers. Uniqueness on integration_id with a one-hour period
  prevents duplicate concurrent syncs for the same integration.

  ## Test HTTP injection

  Tests may pass an `http_plug` in job args for HTTP interception. Because
  Oban.Testing.perform_job/3 JSON-encodes all args, function references cannot
  survive the round-trip directly. The `MetricFlowTest.PlugStore` module (compiled
  only in test) stores the function under a string key when `JSON.Encoder` is
  invoked on the function. This worker resolves string keys back to their
  function via PlugStore at runtime when running in the test environment.
  """

  use Oban.Worker,
    queue: :sync,
    max_attempts: 3,
    unique: [
      fields: [:args],
      keys: [:integration_id],
      period: 3_600,
      states: [:available, :scheduled, :executing]
    ]

  require Logger

  alias MetricFlow.DataSync.DataProviders.FacebookAds
  alias MetricFlow.DataSync.DataProviders.GoogleAds
  alias MetricFlow.DataSync.DataProviders.GoogleAnalytics
  alias MetricFlow.DataSync.DataProviders.QuickBooks
  alias MetricFlow.DataSync.SyncHistoryRepository
  alias MetricFlow.DataSync.SyncJobRepository
  alias MetricFlow.Integrations
  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User

  # ---------------------------------------------------------------------------
  # Oban.Worker callback
  # ---------------------------------------------------------------------------

  @doc """
  Orchestrates the full sync execution for an integration.

  Extracts integration_id, user_id, and sync_job_id from the Oban.Job args,
  updates the SyncJob to :running, fetches data via the appropriate provider,
  persists metrics, creates a SyncHistory record, and transitions the SyncJob
  to :completed or :failed.
  """
  @impl Oban.Worker
  @spec perform(Oban.Job.t()) :: :ok | {:error, term()}
  def perform(%Oban.Job{args: args}) do
    integration_id = Map.get(args, "integration_id")
    user_id = Map.get(args, "user_id")
    sync_job_id = Map.get(args, "sync_job_id")
    http_plug = resolve_plug(Map.get(args, "http_plug"))

    scope = build_scope(user_id)
    started_at = DateTime.utc_now()

    Logger.info(
      "SyncWorker starting sync integration_id=#{integration_id} user_id=#{user_id} sync_job_id=#{sync_job_id}"
    )

    case update_job_status(scope, sync_job_id, :running) do
      {:ok, _job} ->
        result =
          try do
            execute_sync(scope, integration_id, sync_job_id, http_plug, started_at)
          rescue
            e ->
              error_message = Exception.message(e)

              Logger.error(
                "SyncWorker encountered exception integration_id=#{integration_id} user_id=#{user_id} error=#{error_message}"
              )

              record_failure_with_integration(
                scope,
                integration_id,
                sync_job_id,
                error_message,
                started_at
              )

              {:error, {:exception, error_message}}
          end

        finalize_job(scope, sync_job_id, integration_id, user_id, result)

      {:error, _reason} ->
        Logger.error(
          "SyncWorker could not update sync job status to running sync_job_id=#{sync_job_id} user_id=#{user_id}"
        )

        {:error, :sync_job_not_found}
    end
  end

  # ---------------------------------------------------------------------------
  # Public helpers
  # ---------------------------------------------------------------------------

  @doc """
  Maps an integration provider atom to the corresponding data provider module(s).

  The `:google` provider returns multiple data provider modules because a single
  Google OAuth connection grants access to multiple services (Analytics, Ads)
  based on the granted scopes.

  Returns {:ok, [module]} for supported sync providers and
  {:error, :unsupported_provider} for unsupported or unknown providers.
  """
  @spec providers_for(atom()) :: {:ok, [module()]} | {:error, :unsupported_provider}
  def providers_for(:google), do: {:ok, [GoogleAnalytics, GoogleAds]}
  def providers_for(:google_analytics), do: {:ok, [GoogleAnalytics]}
  def providers_for(:google_ads), do: {:ok, [GoogleAds]}
  def providers_for(:facebook_ads), do: {:ok, [FacebookAds]}
  def providers_for(:quickbooks), do: {:ok, [QuickBooks]}
  def providers_for(_), do: {:error, :unsupported_provider}

  # Backwards-compatible single-provider lookup
  @spec provider_for(atom()) :: {:ok, module()} | {:error, :unsupported_provider}
  def provider_for(:google_analytics), do: {:ok, GoogleAnalytics}
  def provider_for(:google_ads), do: {:ok, GoogleAds}
  def provider_for(:facebook_ads), do: {:ok, FacebookAds}
  def provider_for(:quickbooks), do: {:ok, QuickBooks}
  def provider_for(_), do: {:error, :unsupported_provider}

  # ---------------------------------------------------------------------------
  # Private helpers — orchestration
  # ---------------------------------------------------------------------------

  defp build_scope(user_id) do
    Scope.for_user(%User{id: user_id})
  end

  defp update_job_status(scope, sync_job_id, status) do
    SyncJobRepository.update_sync_job_status(scope, sync_job_id, status)
  end

  defp finalize_job(_scope, _sync_job_id, integration_id, user_id, :ok) do
    Logger.info(
      "SyncWorker completed sync successfully integration_id=#{integration_id} user_id=#{user_id}"
    )

    :ok
  end

  defp finalize_job(scope, sync_job_id, integration_id, user_id, {:error, reason} = error) do
    Logger.error(
      "SyncWorker sync failed integration_id=#{integration_id} user_id=#{user_id} reason=#{inspect(reason)}"
    )

    update_job_status(scope, sync_job_id, :failed)
    error
  end

  defp execute_sync(scope, integration_id, sync_job_id, http_plug, started_at) do
    case fetch_integration(integration_id) do
      {:error, :integration_not_found} ->
        {:error, :integration_not_found}

      {:ok, integration} ->
        case ensure_fresh_tokens(scope, integration) do
          {:ok, fresh_integration} ->
            run_provider_sync(scope, fresh_integration, sync_job_id, http_plug, started_at)

          {:error, :token_expired} ->
            error_message = "Token expired and could not be refreshed"

            record_history(
              scope,
              integration,
              sync_job_id,
              :failed,
              0,
              error_message,
              started_at
            )

            {:error, :token_expired}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp run_provider_sync(scope, integration, sync_job_id, http_plug, started_at) do
    case providers_for(integration.provider) do
      {:error, :unsupported_provider} ->
        {:error, :unsupported_provider}

      {:ok, provider_mods} ->
        opts = build_fetch_opts(http_plug)
        run_all_providers(scope, integration, sync_job_id, provider_mods, opts, started_at)
    end
  end

  defp run_all_providers(scope, integration, sync_job_id, provider_mods, opts, started_at) do
    results =
      Enum.map(provider_mods, fn provider_mod ->
        case provider_mod.fetch_metrics(integration, opts) do
          {:ok, metrics} ->
            {:ok, provider_mod, metrics}

          {:error, reason} ->
            Logger.error(
              "SyncWorker provider fetch_metrics failed integration_id=#{integration.id} provider_mod=#{inspect(provider_mod)} reason=#{inspect(reason)}"
            )

            {:error, provider_mod, reason}
        end
      end)

    all_metrics = Enum.flat_map(results, fn
      {:ok, _mod, metrics} -> metrics
      {:error, _mod, _reason} -> []
    end)

    errors = Enum.filter(results, &match?({:error, _, _}, &1))

    if length(errors) == length(provider_mods) do
      error_message =
        Enum.map_join(errors, "; ", fn {:error, mod, reason} ->
          "#{inspect(mod)}: #{format_error(reason)}"
        end)

      record_history(scope, integration, sync_job_id, :failed, 0, error_message, started_at)
      {:error, :all_providers_failed}
    else
      persist_and_record_success(scope, integration, sync_job_id, all_metrics, started_at)
    end
  end

  defp fetch_integration(integration_id) do
    case Integrations.get_integration_by_id(integration_id) do
      {:ok, integration} -> {:ok, integration}
      {:error, :not_found} -> {:error, :integration_not_found}
    end
  end

  defp ensure_fresh_tokens(scope, %Integration{} = integration) do
    cond do
      not Integration.expired?(integration) ->
        {:ok, integration}

      Integration.has_refresh_token?(integration) ->
        case Integrations.refresh_token(scope, integration) do
          {:ok, refreshed} -> {:ok, refreshed}
          {:error, _reason} -> {:error, :token_expired}
        end

      true ->
        {:error, :token_expired}
    end
  end

  defp build_fetch_opts(nil), do: []
  defp build_fetch_opts(plug), do: [http_plug: plug]

  # Resolves the http_plug from job args. In production, there is no http_plug
  # and this returns nil. In tests, the value may be:
  # - A function reference (when perform/1 is called directly without JSON recoding)
  # - A string registry key (after JSON round-trip via MetricFlowTest.PlugStore)
  #
  # :erlang.apply/3 is used for the PlugStore call to avoid a compile-time
  # warning about the module being unavailable in non-test environments while
  # also satisfying the credo rule that discourages Elixir's apply/3 when the
  # argument count is statically known.
  defp resolve_plug(nil), do: nil
  defp resolve_plug(fun) when is_function(fun), do: fun

  defp resolve_plug(key) when is_binary(key) do
    plug_store = Module.concat([MetricFlowTest, PlugStore])

    if Code.ensure_loaded?(plug_store) do
      case :erlang.apply(plug_store, :fetch, [key]) do
        {:ok, fun} -> fun
        {:error, :not_found} -> nil
      end
    end
  end

  defp resolve_plug(_), do: nil

  defp persist_and_record_success(scope, integration, sync_job_id, metrics, started_at) do
    {records_synced, _errors} =
      Enum.reduce(metrics, {0, []}, fn metric_attrs, {count, errors} ->
        case Metrics.create_metric(scope, metric_attrs) do
          {:ok, _metric} -> {count + 1, errors}
          {:error, reason} -> {count, [reason | errors]}
        end
      end)

    record_history(scope, integration, sync_job_id, :success, records_synced, nil, started_at)

    case update_job_status(scope, sync_job_id, :completed) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp record_failure_with_integration(scope, integration_id, sync_job_id, error_message, started_at) do
    case fetch_integration(integration_id) do
      {:ok, integration} ->
        record_history(scope, integration, sync_job_id, :failed, 0, error_message, started_at)

      {:error, _} ->
        :ok
    end
  end

  defp record_history(scope, integration, sync_job_id, status, records_synced, error_message, started_at) do
    now = DateTime.utc_now()

    attrs = %{
      integration_id: integration.id,
      sync_job_id: sync_job_id,
      provider: integration.provider,
      status: status,
      records_synced: records_synced,
      error_message: error_message,
      started_at: started_at,
      completed_at: now
    }

    case SyncHistoryRepository.create_sync_history(scope, attrs) do
      {:ok, _history} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "SyncWorker failed to create SyncHistory integration_id=#{integration.id} sync_job_id=#{sync_job_id} reason=#{inspect(reason)}"
        )

        :ok
    end
  end

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
