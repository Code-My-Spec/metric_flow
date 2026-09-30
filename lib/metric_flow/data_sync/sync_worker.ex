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
  alias MetricFlow.DataSync.DataProviders.GoogleBusiness
  alias MetricFlow.DataSync.DataProviders.GoogleSearchConsole
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
                "SyncWorker encountered exception integration_id=#{integration_id} " <>
                  "user_id=#{user_id} error=#{error_message}"
              )

              record_failure_with_integration(
                scope,
                integration_id,
                sync_job_id,
                nil,
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
  def providers_for(:google_search_console), do: {:ok, [GoogleSearchConsole]}
  def providers_for(:google_business), do: {:ok, [GoogleBusiness]}
  def providers_for(:google_business_reviews), do: {:ok, [GoogleBusiness]}
  def providers_for(:quickbooks), do: {:ok, [QuickBooks]}
  def providers_for(_), do: {:error, :unsupported_provider}

  # Backwards-compatible single-provider lookup
  @spec provider_for(atom()) :: {:ok, module()} | {:error, :unsupported_provider}
  def provider_for(:google_analytics), do: {:ok, GoogleAnalytics}
  def provider_for(:google_ads), do: {:ok, GoogleAds}
  def provider_for(:facebook_ads), do: {:ok, FacebookAds}
  def provider_for(:google_search_console), do: {:ok, GoogleSearchConsole}
  def provider_for(:google_business), do: {:ok, GoogleBusiness}
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

    case fetch_integration(integration_id) do
      {:ok, integration} ->
        broadcast_sync_event(
          user_id,
          {:sync_failed,
           %{
             provider: integration.provider,
             reason: format_error(reason)
           }}
        )

      _ ->
        :ok
    end

    error
  end

  defp execute_sync(scope, integration_id, sync_job_id, http_plug, started_at) do
    case fetch_integration(integration_id) do
      {:error, :integration_not_found} ->
        {:error, :integration_not_found}

      {:ok, integration} ->
        sync_type = determine_sync_type(integration_id)
        date_range = determine_date_range(scope, integration, sync_type)

        sync_with_fresh_tokens(
          scope,
          integration,
          sync_job_id,
          sync_type,
          date_range,
          http_plug,
          started_at
        )
    end
  end

  defp determine_sync_type(integration_id) do
    if SyncHistoryRepository.has_prior_sync_history?(integration_id) do
      :incremental
    else
      :initial
    end
  end

  # First syncs use each provider's own default backfill window. For
  # incremental syncs, anchor to the day after the provider's own last
  # stored metric rather than the wall-clock date, so a sync that has never
  # actually persisted data (e.g. every prior run failed) still falls back
  # to a full backfill instead of narrowing to a window with nothing in it.
  defp determine_date_range(_scope, _integration, :initial), do: nil

  defp determine_date_range(scope, integration, :incremental) do
    case Metrics.get_latest_metric_date(scope, integration.provider) do
      nil -> nil
      last_date -> {Date.add(last_date, 1), Date.add(Date.utc_today(), -1)}
    end
  end

  defp sync_with_fresh_tokens(
         scope,
         integration,
         sync_job_id,
         sync_type,
         date_range,
         http_plug,
         started_at
       ) do
    case ensure_fresh_tokens(scope, integration) do
      {:ok, fresh_integration} ->
        run_provider_sync(
          scope,
          fresh_integration,
          sync_job_id,
          sync_type,
          date_range,
          http_plug,
          started_at
        )

      {:error, :token_expired} ->
        error_message = "Token expired and could not be refreshed"

        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          status: :failed,
          records_synced: 0,
          error_message: error_message
        })

        broadcast_sync_event(
          scope.user.id,
          {:sync_failed,
           %{
             provider: integration.provider,
             reason: error_message,
             completed_at: DateTime.utc_now(),
             sync_type: sync_type
           }}
        )

        {:error, :token_expired}
    end
  end

  defp run_provider_sync(scope, integration, sync_job_id, sync_type, date_range, http_plug, started_at) do
    case providers_for(integration.provider) do
      {:error, :unsupported_provider} ->
        error_message = "#{integration.provider} is not yet supported for automated sync"

        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          status: :failed,
          records_synced: 0,
          error_message: error_message
        })

        broadcast_sync_event(
          scope.user.id,
          {:sync_failed,
           %{
             provider: integration.provider,
             reason: error_message,
             completed_at: DateTime.utc_now(),
             sync_type: sync_type
           }}
        )

        {:error, :unsupported_provider}

      {:ok, provider_mods} ->
        opts = build_fetch_opts(http_plug, date_range)

        run_all_providers(
          scope,
          integration,
          sync_job_id,
          sync_type,
          provider_mods,
          opts,
          started_at
        )
    end
  end

  defp run_all_providers(scope, integration, sync_job_id, sync_type, provider_mods, opts, started_at) do
    results = Enum.map(provider_mods, &fetch_provider_metrics(&1, integration, opts))

    all_metrics =
      Enum.flat_map(results, fn
        {:ok, _mod, metrics} -> metrics
        {:error, _mod, _reason} -> []
      end)

    errors = Enum.filter(results, &match?({:error, _, _}, &1))

    if length(errors) == length(provider_mods) do
      Enum.each(errors, fn {:error, mod, reason} ->
        provider = provider_name(mod, integration)
        error_msg = format_error(reason)

        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          provider: provider,
          status: :failed,
          records_synced: 0,
          error_message: error_msg
        })
      end)

      {:error, _first_mod, first_reason} = hd(errors)

      broadcast_sync_event(
        scope.user.id,
        {:sync_failed,
         %{
           provider: integration.provider,
           reason: format_error(first_reason),
           completed_at: DateTime.utc_now(),
           sync_type: sync_type
         }}
      )

      {:error, :all_providers_failed}
    else
      persist_and_record_success(
        scope,
        integration,
        sync_job_id,
        sync_type,
        all_metrics,
        results,
        started_at
      )
    end
  end

  defp fetch_provider_metrics(provider_mod, integration, opts) do
    case provider_mod.fetch_metrics(integration, opts) do
      {:ok, metrics} ->
        {:ok, provider_mod, metrics}

      {:error, reason} ->
        Logger.error(
          "SyncWorker provider fetch_metrics failed integration_id=#{integration.id} " <>
            "provider_mod=#{inspect(provider_mod)} reason=#{inspect(reason)}"
        )

        {:error, provider_mod, reason}
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

  defp build_fetch_opts(http_plug, date_range) do
    []
    |> maybe_put(:http_plug, http_plug)
    |> maybe_put(:date_range, date_range)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

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

  defp persist_and_record_success(
         scope,
         integration,
         sync_job_id,
         sync_type,
         metrics,
         results,
         started_at
       ) do
    {records_synced, _errors} =
      Enum.reduce(metrics, {0, []}, fn metric_attrs, {count, errors} ->
        # Ensure all top-level keys are atoms to avoid mixed-key maps after
        # Map.put(:user_id, ...) in the repository layer.
        safe_attrs = atomize_keys(metric_attrs)

        case Metrics.create_metric(scope, safe_attrs) do
          {:ok, _metric} -> {count + 1, errors}
          {:error, reason} -> {count, [reason | errors]}
        end
      end)

    # Record a history entry per provider module
    Enum.each(results, fn
      {:ok, mod, mod_metrics} ->
        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          provider: provider_name(mod, integration),
          status: :success,
          records_synced: length(mod_metrics),
          error_message: nil
        })

      {:error, mod, reason} ->
        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          provider: provider_name(mod, integration),
          status: :failed,
          records_synced: 0,
          error_message: format_error(reason)
        })
    end)

    broadcast_sync_event(
      scope.user.id,
      {:sync_completed,
       %{
         provider: integration.provider,
         records_synced: records_synced,
         completed_at: DateTime.utc_now(),
         sync_type: sync_type
       }}
    )

    case update_job_status(scope, sync_job_id, :completed) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp record_failure_with_integration(
         scope,
         integration_id,
         sync_job_id,
         sync_type,
         error_message,
         started_at
       ) do
    case fetch_integration(integration_id) do
      {:ok, integration} ->
        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          status: :failed,
          records_synced: 0,
          error_message: error_message
        })

        broadcast_sync_event(
          scope.user.id,
          {:sync_failed,
           %{
             provider: integration.provider,
             reason: error_message,
             completed_at: DateTime.utc_now(),
             sync_type: sync_type
           }}
        )

      {:error, _} ->
        :ok
    end
  end

  # GoogleBusiness.provider/0 always returns :google_business even when the
  # triggering integration is :google_business_reviews (both share the same
  # fetch_metrics/2 call, see its moduledoc) -- the integration's own
  # declared provider is the correct label except for the :google fan-out
  # case, where a single integration produces per-service history entries
  # and the module's own identity is what distinguishes them.
  defp provider_name(_mod, %Integration{provider: provider}) when provider != :google, do: provider

  defp provider_name(mod, %Integration{provider: :google}) do
    if function_exported?(mod, :provider, 0), do: mod.provider(), else: :google
  end

  defp record_history(scope, integration, sync_job_id, sync_type, started_at, outcome) do
    attrs = %{
      integration_id: integration.id,
      sync_job_id: sync_job_id,
      provider: Map.get(outcome, :provider, integration.provider),
      status: outcome.status,
      sync_type: sync_type,
      records_synced: outcome.records_synced,
      error_message: outcome.error_message,
      started_at: started_at,
      completed_at: DateTime.utc_now()
    }

    case SyncHistoryRepository.create_sync_history(scope, attrs) do
      {:ok, _history} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "SyncWorker failed to create SyncHistory integration_id=#{integration.id} " <>
            "sync_job_id=#{sync_job_id} reason=#{inspect(reason)}"
        )

        :ok
    end
  end

  # Converts string keys to atoms at the top level only. Nested maps (e.g.
  # dimensions) are left as-is since Ecto stores them as JSON.
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_existing_atom(k), v}
      {k, v} -> {k, v}
    end)
  rescue
    ArgumentError -> map
  end

  defp broadcast_sync_event(user_id, message) do
    Phoenix.PubSub.broadcast(MetricFlow.PubSub, "user:#{user_id}:sync", message)
  end

  defp format_error(:missing_property_id) do
    "No Google Analytics property configured. " <>
      "Go to the integration's account selection to choose a property."
  end

  defp format_error(:missing_customer_id) do
    "No Google Ads customer ID configured. " <>
      "Go to the integration's account selection to choose an account."
  end

  defp format_error(:unauthorized), do: "Authorization expired. Please reconnect the integration."

  defp format_error(:token_expired),
    do: "Token expired and could not be refreshed. Please reconnect."

  defp format_error(:all_providers_failed),
    do: "All data providers failed. Check your integration settings."

  defp format_error({:exception, _message}),
    do: "An unexpected error occurred during sync. Please try again."

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
