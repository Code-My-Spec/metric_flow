defmodule MetricFlow.DataSync.SyncWorker do
  @moduledoc """
  Oban worker that executes data sync operations for a single integration.

  Receives integration_id, account_id, user_id (who triggered it) and
  sync_job_id in Oban job args. Runs with a system scope for the
  integration's account. Updates
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
      keys: [:integration_id, :product],
      period: 3_600,
      states: [:available, :scheduled, :executing]
    ]

  @gbp_providers [:google_business, :google_business_reviews]

  require Logger

  alias MetricFlow.AccountAccess
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

    http_plug =
      resolve_plug(Map.get(args, "http_plug")) || resolve_product_plugs(args["http_plugs"])

    breakdown = resolve_breakdown(Map.get(args, "breakdown"))
    product = Map.get(args, "product")

    scope = build_scope(args, integration_id)
    started_at = DateTime.utc_now()

    Logger.info(
      "SyncWorker starting sync integration_id=#{integration_id} user_id=#{user_id} sync_job_id=#{sync_job_id}"
    )

    case update_job_status(scope, sync_job_id, :running) do
      {:ok, _job} ->
        result =
          try do
            execute_sync(
              scope,
              integration_id,
              sync_job_id,
              {http_plug, breakdown, product},
              started_at
            )
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

  The `:google` provider returns every Google product's module: the account's
  one Google integration holds Analytics, Ads, Search Console and Business
  Profile. A sync runs only the products whose scope is granted and whose
  selection is saved (or the one product a job names).

  Returns {:ok, [module]} for supported sync providers and
  {:error, :unsupported_provider} for unsupported or unknown providers.
  """
  @spec providers_for(atom()) :: {:ok, [module()]} | {:error, :unsupported_provider}
  def providers_for(:google),
    do: {:ok, [GoogleAnalytics, GoogleAds, GoogleSearchConsole, GoogleBusiness]}

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

  # Syncs act on the integration's account, not on whoever triggered them:
  # a system scope for that account (the integration is the source of truth;
  # the account_id arg covers an integration that has since been deleted).
  defp build_scope(args, integration_id) do
    account_id =
      case fetch_integration(integration_id) do
        {:ok, %Integration{account_id: account_id}} when is_integer(account_id) -> account_id
        _ -> Map.get(args, "account_id") || sync_job_account_id(Map.get(args, "sync_job_id"))
      end

    case account_id do
      id when is_integer(id) -> Scope.for_account(id)
      _ -> %Scope{user: nil, account_id: nil}
    end
  end

  defp sync_job_account_id(sync_job_id) when is_integer(sync_job_id) do
    case MetricFlow.Repo.get(MetricFlow.DataSync.SyncJob, sync_job_id) do
      %{account_id: account_id} -> account_id
      nil -> nil
    end
  end

  defp sync_job_account_id(_sync_job_id), do: nil

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
          scope.account_id,
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

  defp execute_sync(scope, integration_id, sync_job_id, run_opts, started_at) do
    {http_plug, breakdown, product} = run_opts

    case fetch_integration(integration_id) do
      {:error, :integration_not_found} ->
        {:error, :integration_not_found}

      {:ok, %Integration{provider: :youtube} = integration} ->
        run_youtube_sync(scope, integration, sync_job_id, http_plug, started_at)

      {:ok, integration} ->
        sync_type = determine_sync_type(integration_id)
        plans = plan_modules(scope, integration, product, sync_type)

        cond do
          match?({:ok, [_ | _]}, plans) and
              Enum.all?(elem(plans, 1), fn {_mod, range} -> already_current?(range) end) ->
            record_up_to_date(scope, integration, sync_job_id, sync_type, started_at)

          true ->
            sync_with_fresh_tokens(
              scope,
              integration,
              sync_job_id,
              sync_type,
              plans,
              {http_plug, breakdown},
              started_at
            )
        end
    end
  end

  # Which data-provider modules this run uses, each with its own date
  # window: a module's incremental window starts after the last metric it
  # wrote (tagged with its product, e.g. :google_ads), not after the
  # integration's — the `:google` integration has no metrics of its own.
  defp plan_modules(scope, integration, product, sync_type) do
    with {:ok, mods} <- modules_to_run(integration, product) do
      {:ok,
       Enum.map(mods, fn mod ->
         tag = provider_name(mod, integration)

         range =
           scope
           |> determine_date_range(tag, sync_type)
           |> refetch_last_day_if_idempotent(tag)

         {mod, range}
       end)}
    end
  end

  # A job naming a product syncs just that product. Otherwise the Google
  # integration syncs every product that is granted and has a selection;
  # the rest are skipped, not failed.
  defp modules_to_run(%Integration{provider: :google} = integration, product) do
    {:ok, mods} = providers_for(:google)

    {:ok,
     Enum.filter(mods, fn mod ->
       if product,
         do: Atom.to_string(mod.provider()) == product,
         else:
           Integrations.product_granted?(integration, mod.provider()) and
             Integrations.product_selected?(integration, mod.provider())
     end)}
  end

  defp modules_to_run(integration, _product), do: providers_for(integration.provider)

  defp complete_job(scope, sync_job_id) do
    case update_job_status(scope, sync_job_id, :completed) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # An incremental sync after the data already reaches yesterday has an
  # empty window (start after end). Providers reject that range (GA4 and
  # Meta 400, QuickBooks invalid_date_range), so a second "Sync now" on the
  # same day used to fail. It is simply up to date.
  # Business Profile writes replace (location, day) rows rather than append
  # (see delete_stale_performance_metrics/2), so a same-day re-sync can safely
  # re-fetch the last day and pick up corrected values instead of skipping.
  defp refetch_last_day_if_idempotent({%Date{} = from, %Date{} = to}, provider)
       when provider in @gbp_providers do
    if Date.compare(from, to) == :gt, do: {to, to}, else: {from, to}
  end

  defp refetch_last_day_if_idempotent(range, _provider), do: range

  defp already_current?({%Date{} = from, %Date{} = to}), do: Date.compare(from, to) == :gt
  defp already_current?(_), do: false

  defp record_up_to_date(scope, integration, sync_job_id, sync_type, started_at) do
    record_history(scope, integration, sync_job_id, sync_type, started_at, %{
      status: :success,
      records_synced: 0,
      error_message: nil
    })

    broadcast_sync_event(
      scope.account_id,
      {:sync_completed,
       %{
         provider: integration.provider,
         records_synced: 0,
         completed_at: DateTime.utc_now(),
         sync_type: sync_type
       }}
    )

    case update_job_status(scope, sync_job_id, :completed) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp run_youtube_sync(scope, integration, sync_job_id, http_plug, started_at) do
    scope = Scope.put_account_id(scope, integration.account_id)
    sync_type = determine_sync_type(integration.id)

    result =
      with {:ok, job} <- SyncJobRepository.get_sync_job(scope, sync_job_id),
           true <- job.integration_id == integration.id,
           :ok <- Integrations.authorize_youtube_connection(scope),
           {:ok, fresh} <- ensure_fresh_tokens(scope, integration) do
        MetricFlow.DataSync.YouTubeSync.sync(scope, fresh, maybe_put([], :http_plug, http_plug))
      else
        false -> {:error, :unauthorized}
        {:error, _} = error -> error
      end

    outcome = MetricFlow.DataSync.YouTubeSyncOutcome.summarize(result)
    record_history(scope, integration, sync_job_id, sync_type, started_at, outcome)

    if outcome.status == :failed do
      {:error, :youtube_sync_failed}
    else
      broadcast_sync_event(
        scope.account_id,
        {:sync_completed,
         %{
           provider: :youtube,
           records_synced: outcome.records_synced,
           completed_at: DateTime.utc_now(),
           sync_type: sync_type
         }}
      )

      case update_job_status(scope, sync_job_id, :completed) do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
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
  defp determine_date_range(_scope, _provider, :initial), do: nil

  defp determine_date_range(scope, provider, :incremental) do
    case Metrics.get_latest_metric_date(scope, provider) do
      nil -> nil
      last_date -> {Date.add(last_date, 1), Date.add(Date.utc_today(), -1)}
    end
  end

  defp sync_with_fresh_tokens(
         scope,
         integration,
         sync_job_id,
         sync_type,
         plans,
         fetch_opts,
         started_at
       ) do
    case ensure_fresh_tokens(scope, integration) do
      {:ok, fresh_integration} ->
        run_provider_sync(
          scope,
          fresh_integration,
          sync_job_id,
          sync_type,
          plans,
          fetch_opts,
          started_at
        )

      {:error, :token_expired} ->
        error_message = "Token expired and could not be refreshed"

        for provider <- failed_products(integration, plans) do
          record_history(scope, integration, sync_job_id, sync_type, started_at, %{
            provider: provider,
            status: :failed,
            records_synced: 0,
            error_message: error_message
          })

          broadcast_sync_event(
            scope.account_id,
            {:sync_failed,
             %{
               provider: provider,
               reason: error_message,
               completed_at: DateTime.utc_now(),
               sync_type: sync_type
             }}
          )
        end

        {:error, :token_expired}
    end
  end

  # An expired Google sign-in fails each product the run was going to sync,
  # so every product's history shows why it stopped.
  defp failed_products(%Integration{provider: :google} = integration, {:ok, [_ | _] = plans}),
    do: Enum.map(plans, fn {mod, _range} -> provider_name(mod, integration) end)

  defp failed_products(integration, _plans), do: [integration.provider]

  defp run_provider_sync(
         scope,
         integration,
         sync_job_id,
         sync_type,
         plans,
         {http_plug, breakdown},
         started_at
       ) do
    case plans do
      # Nothing set up to sync on this Google sign-in (its token is still
      # checked above, so a broken sign-in is reported, not skipped).
      {:ok, []} ->
        complete_job(scope, sync_job_id)

      {:error, :unsupported_provider} ->
        error_message = "#{integration.provider} is not yet supported for automated sync"

        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          status: :failed,
          records_synced: 0,
          error_message: error_message
        })

        broadcast_sync_event(
          scope.account_id,
          {:sync_failed,
           %{
             provider: integration.provider,
             reason: error_message,
             completed_at: DateTime.utc_now(),
             sync_type: sync_type
           }}
        )

        {:error, :unsupported_provider}

      {:ok, plans} ->
        run_all_providers(
          scope,
          integration,
          sync_job_id,
          sync_type,
          plans,
          {http_plug, breakdown},
          started_at
        )
    end
  end

  defp run_all_providers(
         scope,
         integration,
         sync_job_id,
         sync_type,
         plans,
         {http_plug, breakdown},
         started_at
       ) do
    ranges = Map.new(plans, fn {mod, range} -> {mod, range} end)

    # A module whose data already reaches yesterday has nothing to fetch
    # this run; it records an up-to-date success alongside the others.
    results =
      Enum.map(plans, fn {mod, range} ->
        if already_current?(range),
          do: {:ok, mod, []},
          else:
            fetch_provider_metrics(
              mod,
              integration,
              build_fetch_opts(plug_for(http_plug, mod, integration), range, breakdown)
            )
      end)

    all_metrics =
      Enum.flat_map(results, fn
        {:ok, _mod, metrics} -> metrics
        {:error, _mod, _reason} -> []
      end)

    errors = Enum.filter(results, &match?({:error, _, _}, &1))

    if length(errors) == length(plans) do
      Enum.each(errors, fn {:error, mod, reason} ->
        provider = provider_name(mod, integration)
        error_msg = format_error(reason, for_module(integration, mod), ranges[mod])

        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          provider: provider,
          status: :failed,
          records_synced: 0,
          error_message: error_msg,
          provider_error_detail: provider_error_detail(reason)
        })
      end)

      {:error, first_mod, first_reason} = hd(errors)

      if integration.provider == :google do
        broadcast_product_outcomes(scope, integration, sync_type, results, ranges)
      else
        broadcast_sync_event(
          scope.account_id,
          {:sync_failed,
           %{
             provider: integration.provider,
             reason:
               format_error(first_reason, for_module(integration, first_mod), ranges[first_mod]),
             completed_at: DateTime.utc_now(),
             sync_type: sync_type
           }}
        )
      end

      {:error, :all_providers_failed}
    else
      persist_and_record_success(
        scope,
        integration,
        sync_job_id,
        sync_type,
        all_metrics,
        results,
        started_at,
        ranges
      )
    end
  end

  defp fetch_provider_metrics(provider_mod, integration, opts) do
    {result, detail} =
      MetricFlow.DataSync.ProviderHttp.capture(
        fn -> provider_mod.fetch_metrics(integration, opts) end,
        [integration.access_token, integration.refresh_token]
      )

    case result do
      {:ok, metrics} ->
        {:ok, provider_mod, metrics}

      {:error, reason} ->
        Logger.error(
          "SyncWorker provider fetch_metrics failed integration_id=#{integration.id} " <>
            "provider_mod=#{inspect(provider_mod)} reason=#{inspect(reason)}"
        )

        reason = if detail, do: {:provider_http_error, reason, detail}, else: reason
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
    # Refresh anything expiring within 5 minutes, so a token doesn't lapse
    # partway through a long backfill.
    cond do
      not Integration.expires_within?(integration, 300) ->
        {:ok, integration}

      Integration.has_refresh_token?(integration) ->
        case Integrations.refresh_token(scope, integration) do
          {:ok, refreshed} ->
            {:ok, refreshed}

          {:error, reason} ->
            Logger.warning(
              "SyncWorker token refresh failed integration_id=#{integration.id} " <>
                "provider=#{integration.provider} reason=#{inspect(reason)}"
            )

            if Integration.expired?(integration),
              do: {:error, :token_expired},
              else: {:ok, integration}
        end

      not Integration.expired?(integration) ->
        {:ok, integration}

      true ->
        {:error, :token_expired}
    end
  end

  defp build_fetch_opts(http_plug, date_range, breakdown) do
    []
    |> maybe_put(:http_plug, http_plug)
    |> maybe_put(:date_range, date_range)
    |> maybe_put(:breakdown, breakdown)
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp resolve_breakdown("adset"), do: :adset
  defp resolve_breakdown("ad_group"), do: :ad_group
  defp resolve_breakdown(_), do: nil

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

  # A Google sync's test plugs arrive per product (product => plug key).
  defp resolve_product_plugs(plugs) when is_map(plugs),
    do: Map.new(plugs, fn {product, key} -> {product, resolve_plug(key)} end)

  defp resolve_product_plugs(_), do: nil

  defp plug_for(plugs, mod, integration) when is_map(plugs),
    do: Map.get(plugs, Atom.to_string(provider_name(mod, integration)))

  defp plug_for(plug, _mod, _integration), do: plug

  defp persist_and_record_success(
         scope,
         integration,
         sync_job_id,
         sync_type,
         metrics,
         results,
         started_at,
         ranges
       ) do
    delete_stale_performance_metrics(scope, metrics)

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

    # Record a history entry per provider module. A module may combine
    # more than one logical provider's data in a single fetch_metrics call
    # (GoogleBusiness fetches both :google_business and
    # :google_business_reviews at once) -- each distinct :provider tag on
    # the returned metrics gets its own history entry.
    Enum.each(results, fn
      {:ok, mod, mod_metrics} ->
        record_success_history(
          scope,
          integration,
          sync_job_id,
          sync_type,
          started_at,
          mod,
          mod_metrics
        )

      {:error, mod, reason} ->
        record_history(scope, integration, sync_job_id, sync_type, started_at, %{
          provider: provider_name(mod, integration),
          status: :failed,
          records_synced: 0,
          error_message: format_error(reason, for_module(integration, mod), ranges[mod]),
          provider_error_detail: provider_error_detail(reason)
        })
    end)

    if integration.provider == :google,
      do: broadcast_product_outcomes(scope, integration, sync_type, results, ranges)

    broadcast_sync_event(
      scope.account_id,
      {:sync_completed,
       %{
         provider: integration.provider,
         records_synced: records_synced,
         completed_at: DateTime.utc_now(),
         sync_type: effective_sync_type(integration.provider, sync_type)
       }}
    )

    case update_job_status(scope, sync_job_id, :completed) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # The `:google` integration's own events name no product, so each product
  # in the run gets its own (live status rows and feeds key on the product).
  defp broadcast_product_outcomes(scope, integration, sync_type, results, ranges) do
    Enum.each(results, fn
      {:ok, mod, mod_metrics} ->
        broadcast_sync_event(
          scope.account_id,
          {:sync_completed,
           %{
             provider: mod.provider(),
             records_synced: length(mod_metrics),
             completed_at: DateTime.utc_now(),
             sync_type: effective_sync_type(mod.provider(), sync_type)
           }}
        )

      {:error, mod, reason} ->
        broadcast_sync_event(
          scope.account_id,
          {:sync_failed,
           %{
             provider: mod.provider(),
             reason: format_error(reason, for_module(integration, mod), ranges[mod]),
             completed_at: DateTime.utc_now(),
             sync_type: sync_type
           }}
        )
    end)
  end

  # Deletes existing Google Business Profile rows for any (provider,
  # location, day) this batch is about to (re)write, so re-running a sync is
  # idempotent even though there is no database-level unique constraint to
  # upsert against. Reviews need this as much as performance does: every
  # sync re-fetches the newest review pages in full, so without it each run
  # inserted the same reviews again.
  defp delete_stale_performance_metrics(scope, metrics) do
    metrics
    |> Enum.filter(&(Map.get(&1, :provider) in @gbp_providers))
    |> Enum.map(fn metric ->
      location_id = get_in(metric, [:dimensions, :location_id])
      {metric.provider, location_id, DateTime.to_date(metric.recorded_at)}
    end)
    |> Enum.uniq()
    |> Enum.each(fn {provider, location_id, date} ->
      Metrics.delete_metrics_by_location_and_date(scope, provider, location_id, date)
    end)
  end

  defp record_success_history(
         scope,
         integration,
         sync_job_id,
         sync_type,
         started_at,
         mod,
         mod_metrics
       ) do
    default_provider = provider_name(mod, integration)
    groups = Enum.group_by(mod_metrics, &Map.get(&1, :provider, default_provider))

    if map_size(groups) == 0 do
      record_history(
        scope,
        integration,
        sync_job_id,
        effective_sync_type(default_provider, sync_type),
        started_at,
        %{
          provider: default_provider,
          status: :success,
          records_synced: 0,
          error_message: nil
        }
      )
    else
      Enum.each(groups, fn {provider, provider_metrics} ->
        record_grouped_success(
          scope,
          integration,
          sync_job_id,
          sync_type,
          started_at,
          default_provider,
          provider,
          provider_metrics
        )
      end)
    end
  end

  # The blanket :sync_completed broadcast after this function's caller
  # already covers default_provider (it fires once per sync, keyed to
  # integration.provider, for the LiveView's real-time list). A module
  # whose metrics span more than one distinct provider tag needs its own
  # extra broadcast per additional tag, or the real-time list never
  # reflects the DB-level split recorded above.
  defp record_grouped_success(
         scope,
         integration,
         sync_job_id,
         sync_type,
         started_at,
         default_provider,
         provider,
         provider_metrics
       ) do
    entry_sync_type = effective_sync_type(provider, sync_type)

    record_history(scope, integration, sync_job_id, entry_sync_type, started_at, %{
      provider: provider,
      status: :success,
      records_synced: length(provider_metrics),
      error_message: nil
    })

    unless provider == default_provider do
      broadcast_sync_event(
        scope.account_id,
        {:sync_completed,
         %{
           provider: provider,
           records_synced: length(provider_metrics),
           completed_at: DateTime.utc_now(),
           sync_type: entry_sync_type
         }}
      )
    end
  end

  # Google Business reviews have no backfill window -- every sync refetches
  # the full review history for the location, so labeling a first sync
  # :initial (which renders an "Initial Sync"/backfill-limit badge implying
  # this run is special) is misleading: every run is equivalent.
  defp effective_sync_type(:google_business_reviews, _sync_type), do: :incremental
  defp effective_sync_type(_provider, sync_type), do: sync_type

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
          scope.account_id,
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
  defp provider_name(_mod, %Integration{provider: provider}) when provider != :google,
    do: provider

  defp provider_name(mod, %Integration{provider: :google}) do
    if function_exported?(mod, :provider, 0), do: mod.provider(), else: :google
  end

  # Error copy is per product: on the `:google` integration, the module's
  # product (Search Console, Ads, …) is the one that failed.
  defp for_module(integration, mod),
    do: %{integration | provider: provider_name(mod, integration)}

  defp record_history(scope, integration, sync_job_id, sync_type, started_at, outcome) do
    attrs = %{
      user_id: integration.user_id,
      integration_id: integration.id,
      sync_job_id: sync_job_id,
      provider: Map.get(outcome, :provider, integration.provider),
      status: outcome.status,
      sync_type: sync_type,
      records_synced: outcome.records_synced,
      error_message: outcome.error_message,
      provider_error_detail: Map.get(outcome, :provider_error_detail),
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

  defp broadcast_sync_event(nil, _message), do: :ok

  defp broadcast_sync_event(account_id, message) do
    Phoenix.PubSub.broadcast(MetricFlow.PubSub, AccountAccess.sync_topic(account_id), message)
  end

  defp provider_error_detail({:provider_http_error, _reason, detail}), do: detail
  defp provider_error_detail(_reason), do: nil

  defp format_error({:provider_http_error, reason, _detail}, integration, date_range),
    do: format_error(reason, integration, date_range)

  defp format_error(:missing_site_url, _integration, date_range) do
    "No Search Console site URL configured#{format_date_range(date_range)}. " <>
      "Go to the integration's account selection to choose a site."
  end

  defp format_error(:site_not_found, integration, date_range) do
    site = site_url_from(integration) || "the configured site"

    "Search Console site #{site} was not found#{format_date_range(date_range)}. " <>
      "It may have been removed or the URL changed."
  end

  defp format_error(
         :insufficient_permissions,
         %Integration{provider: :google_search_console} = integration,
         date_range
       ) do
    site = site_url_from(integration) || "the configured site"

    "Insufficient permissions to access Search Console site #{site}#{format_date_range(date_range)}. " <>
      "Reconnect with an account that has access."
  end

  defp format_error(:insufficient_permissions, %Integration{} = integration, date_range) do
    "Insufficient permissions to access #{provider_display_name(integration.provider)}" <>
      "#{format_date_range(date_range)}. Reconnect with an account that has access."
  end

  defp format_error(:no_locations_configured, _integration, date_range) do
    "No Google Business Profile locations configured#{format_date_range(date_range)}. " <>
      "Go to the integration's account selection to choose a location."
  end

  defp format_error(reason, _integration, _date_range), do: format_error(reason)

  @provider_display_names %{
    google_business: "Google Business Profile",
    google_analytics: "Google Analytics",
    google_ads: "Google Ads",
    facebook_ads: "Facebook Ads",
    quickbooks: "QuickBooks",
    google_search_console: "Google Search Console"
  }

  defp provider_display_name(provider) when is_atom(provider) do
    Map.get(
      @provider_display_names,
      provider,
      provider |> Atom.to_string() |> humanize_provider()
    )
  end

  defp humanize_provider(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp site_url_from(%Integration{provider_metadata: meta}) do
    case Map.get(meta || %{}, "site_url") do
      url when is_binary(url) and url != "" -> url
      _ -> nil
    end
  end

  defp site_url_from(_), do: nil

  defp format_date_range(nil), do: ""

  defp format_date_range({start_date, end_date}),
    do: " (date range: #{start_date} to #{end_date})"

  defp format_error(:missing_property_id) do
    "No Google Analytics property configured. " <>
      "Go to the integration's account selection to choose a property."
  end

  defp format_error(:missing_customer_id) do
    "No Google Ads customer ID configured. " <>
      "Go to the integration's account selection to choose an account."
  end

  defp format_error(:missing_realm_id) do
    "No QuickBooks company (realm) configured. " <>
      "Go to the integration's account selection to choose a company."
  end

  defp format_error(:missing_account_id) do
    "No QuickBooks income account configured. " <>
      "Go to the integration's account selection to choose an account."
  end

  defp format_error(:unauthorized), do: "Authorization expired. Please reconnect the integration."

  defp format_error(:token_expired),
    do: "Token expired and could not be refreshed. Please reconnect."

  defp format_error(:all_providers_failed),
    do: "All data providers failed. Check your integration settings."

  defp format_error({:exception, _message}),
    do: "An unexpected error occurred during sync. Please try again."

  defp format_error({:ga4_api_error, status, details}) do
    api_status = Map.get(details, "status", "UNKNOWN")
    message = Map.get(details, "message", "Request failed")
    "Google Analytics API HTTP #{status} (#{api_status}): #{message}"
  end

  defp format_error({:bad_request, message}) when is_binary(message),
    do: "Google Ads API error: #{message}"

  defp format_error(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
