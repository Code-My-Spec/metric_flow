defmodule MetricFlowWeb.IntegrationLive.SyncHistory do
  @moduledoc """
  LiveView for viewing automated sync status and history.

  Displays the automated daily sync schedule, date range information, and a
  unified list of sync history entries for all connected integrations, covering
  both marketing providers (Google Ads, Facebook Ads, Google Analytics) and
  financial providers (QuickBooks). Handles live sync completion and failure
  broadcasts from SyncWorker, prepending new entries to the list in real time.

  Unauthenticated users are redirected to `/users/log-in` by the router's
  `require_authenticated_user` plug before mount.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.DataSync

  # Provider display names for both marketing and financial platforms.
  @provider_names %{
    google_ads: "Google Ads",
    facebook_ads: "Facebook Ads",
    google_analytics: "Google Analytics",
    google_search_console: "Google Search Console",
    google_business: "Google Business Profile",
    google_business_reviews: "Google Business Reviews",
    quickbooks: "QuickBooks",
    google: "Google"
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
    >
    <div class="mx-auto max-w-3xl mf-content px-4 py-8">
      <div class="mb-8">
        <h1 class="text-2xl font-bold">Sync History</h1>
        <p class="mt-1 text-base-content/60">
          View automated sync results and status
        </p>
      </div>

      <%!-- Schedule section --%>
      <div data-role="sync-schedule" class="mf-card p-5 mb-6">
        <h2 class="text-lg font-semibold">Automated Sync Schedule</h2>
        <p class="mt-1 text-sm text-base-content/60">
          Daily at 2:00 AM UTC — retrieves metrics and financial data per provider, per day.
          Covers marketing providers (Google Ads, Facebook Ads, Google Analytics, Google Business Profile,
          Google Search Console) and financial providers (QuickBooks). On first sync, all available historical data is backfilled.
          Failed syncs are automatically retried up to 3 times with exponential backoff.
        </p>
        <div class="mt-3 flex items-center gap-2 flex-wrap">
          <span class="badge badge-info">Daily</span>
        </div>
      </div>

      <%!-- Date range section --%>
      <div
        data-role="date-range"
        class="flex items-center gap-2 mb-6 text-sm text-base-content/60"
      >
        <span>
          Showing data through {@date_range_end |> Date.to_iso8601()} (yesterday — today excluded, incomplete day)
        </span>
      </div>

      <%!-- Filter tabs --%>
      <div class="flex items-center gap-2 mb-4">
        <button
          phx-click="filter"
          phx-value-status="all"
          data-role="filter-all"
          class={"btn btn-sm #{if @status_filter == "all", do: "btn-primary", else: "btn-ghost"}"}
        >
          All
        </button>
        <button
          phx-click="filter"
          phx-value-status="success"
          data-role="filter-success"
          class={"btn btn-sm #{if @status_filter == "success", do: "btn-primary", else: "btn-ghost"}"}
        >
          Success
        </button>
        <button
          phx-click="filter"
          phx-value-status="failed"
          data-role="filter-failed"
          class={"btn btn-sm #{if @status_filter == "failed", do: "btn-primary", else: "btn-ghost"}"}
        >
          Failed
        </button>
      </div>

      <%!-- Sync history list --%>
      <div data-role="sync-history" class="space-y-3">
        <div :if={@sync_history == [] and @sync_events == []} class="mf-card p-8 text-center">
          <p class="text-base-content/60">No sync history yet.</p>
          <p class="mt-2 text-sm text-base-content/50">
            Initial Sync entries will appear here once the first automated or manual sync runs.
            Each provider sync entry shows the provider name, status, records synced, and date.
            The system backfills all available historical data from each platform on first sync.
          </p>
          <div class="mt-3 flex justify-center gap-2 flex-wrap">
            <span data-sync-type="initial" class="badge badge-ghost">Initial Sync</span>
          </div>
        </div>

        <%!-- Live sync events (prepended first) --%>
        <div
          :for={entry <- filter_events(@sync_events, @status_filter)}
          data-role="sync-history-entry"
          data-status={entry.status}
          class="mf-card p-4"
        >
          <.sync_entry entry={entry} />
        </div>

        <%!-- Persisted history entries --%>
        <div
          :for={entry <- filter_history(@sync_history, @status_filter)}
          data-role="sync-history-entry"
          data-status={to_string(entry.status)}
          class="mf-card p-4"
        >
          <.persisted_entry entry={entry} />
        </div>
      </div>
    </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Live entry component (for real-time sync_events)
  # ---------------------------------------------------------------------------

  attr :entry, :map, required: true

  defp sync_entry(%{entry: %{status: "success"}} = assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <div class="flex items-center gap-2 flex-wrap">
          <span class="font-semibold" data-role="sync-provider">
            {provider_display_name(@entry.provider)}
          </span>
          <span class="badge badge-success">Success</span>
          <span :if={@entry[:sync_type] == :initial} data-sync-type="initial" class="badge badge-ghost">
            Initial Sync
          </span>
        </div>
        <p class="text-sm text-base-content/60 mt-1">
          {@entry.records_synced} records synced
        </p>
        <p :if={@entry[:completed_at]} class="text-xs text-base-content/50 mt-0.5">
          Completed at {format_datetime(@entry.completed_at)}
        </p>
      </div>
      <div class="text-right">
        <p :if={@entry[:data_date]} class="text-xs text-base-content/50">
          Date: {Date.to_iso8601(@entry.data_date)}
        </p>
      </div>
    </div>
    """
  end

  defp sync_entry(%{entry: %{status: "failed"}} = assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <div class="flex items-center gap-2 flex-wrap">
          <span class="font-semibold" data-role="sync-provider">
            {provider_display_name(@entry.provider)}
          </span>
          <span class="badge badge-error">Failed</span>
        </div>
        <p :if={@entry[:reason]} data-role="sync-error" class="text-sm text-error mt-1">
          {@entry.reason}
        </p>
        <p
          :if={Map.has_key?(@entry, :attempt) and Map.has_key?(@entry, :max_attempts)}
          class="text-xs text-base-content/50 mt-0.5"
        >
          Attempt {@entry.attempt}/{@entry.max_attempts}
        </p>
      </div>
      <div class="text-right">
        <p :if={@entry[:data_date]} class="text-xs text-base-content/50">
          Date: {Date.to_iso8601(@entry.data_date)}
        </p>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Persisted entry component (for sync_history from DB)
  # ---------------------------------------------------------------------------

  attr :entry, :any, required: true

  defp persisted_entry(%{entry: %{status: :success}} = assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <div class="flex items-center gap-2 flex-wrap">
          <span class="font-semibold" data-role="sync-provider">
            {provider_display_name(@entry.provider)}
          </span>
          <span class="badge badge-success">Success</span>
        </div>
        <p class="text-sm text-base-content/60 mt-1">
          {@entry.records_synced} records synced
        </p>
        <p :if={@entry.completed_at} class="text-xs text-base-content/50 mt-0.5">
          Completed at {format_datetime(@entry.completed_at)}
        </p>
      </div>
      <div class="text-right">
        <p :if={@entry.completed_at} class="text-xs text-base-content/50">
          Date: {Date.to_iso8601(DateTime.to_date(@entry.completed_at))}
        </p>
      </div>
    </div>
    """
  end

  defp persisted_entry(%{entry: %{status: :failed}} = assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <div class="flex items-center gap-2 flex-wrap">
          <span class="font-semibold" data-role="sync-provider">
            {provider_display_name(@entry.provider)}
          </span>
          <span class="badge badge-error">Failed</span>
        </div>
        <p :if={@entry.error_message} data-role="sync-error" class="text-sm text-error mt-1">
          {@entry.error_message}
        </p>
      </div>
      <div class="text-right">
        <p :if={@entry.completed_at} class="text-xs text-base-content/50">
          Date: {Date.to_iso8601(DateTime.to_date(@entry.completed_at))}
        </p>
      </div>
    </div>
    """
  end

  defp persisted_entry(%{entry: %{status: :partial_success}} = assigns) do
    ~H"""
    <div class="flex items-center justify-between">
      <div>
        <div class="flex items-center gap-2 flex-wrap">
          <span class="font-semibold" data-role="sync-provider">
            {provider_display_name(@entry.provider)}
          </span>
          <span class="badge badge-warning">Partial</span>
        </div>
        <p class="text-sm text-base-content/60 mt-1">
          {@entry.records_synced} records synced
        </p>
        <p :if={@entry.error_message} data-role="sync-error" class="text-sm text-error mt-1">
          {@entry.error_message}
        </p>
        <p :if={@entry.completed_at} class="text-xs text-base-content/50 mt-0.5">
          Completed at {format_datetime(@entry.completed_at)}
        </p>
      </div>
      <div class="text-right">
        <p :if={@entry.completed_at} class="text-xs text-base-content/50">
          Date: {Date.to_iso8601(DateTime.to_date(@entry.completed_at))}
        </p>
      </div>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    sync_history = DataSync.list_sync_history(scope)

    date_range_end = Date.add(Date.utc_today(), -1)
    date_range_start = Date.add(date_range_end, -30)

    socket =
      socket
      |> assign(:sync_history, sync_history)
      |> assign(:date_range_start, date_range_start)
      |> assign(:date_range_end, date_range_end)
      |> assign(:sync_events, [])
      |> assign(:status_filter, "all")
      |> assign(:page_title, "Sync History")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter", %{"status" => status}, socket)
      when status in ["all", "success", "failed"] do
    {:noreply, assign(socket, :status_filter, status)}
  end

  # ---------------------------------------------------------------------------
  # Info handlers (real-time sync broadcasts)
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({:sync_completed, payload}, socket) do
    entry = Map.put(payload, :status, "success")
    {:noreply, update(socket, :sync_events, &[entry | &1])}
  end

  def handle_info({:sync_failed, payload}, socket) do
    entry = Map.put(payload, :status, "failed")
    {:noreply, update(socket, :sync_events, &[entry | &1])}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp provider_display_name(provider) when is_atom(provider) do
    case Map.get(@provider_names, provider) do
      nil -> provider |> Atom.to_string() |> derive_display_name()
      name -> name
    end
  end

  defp provider_display_name(provider) when is_binary(provider) do
    provider
    |> String.to_existing_atom()
    |> provider_display_name()
  rescue
    ArgumentError -> derive_display_name(provider)
  end

  defp derive_display_name(provider_str) do
    provider_str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y %H:%M UTC")
  end

  defp format_datetime(_), do: ""

  defp filter_events(events, "all"), do: events
  defp filter_events(events, status), do: Enum.filter(events, &(&1.status == status))

  defp filter_history(history, "all"), do: history
  defp filter_history(history, status) do
    status_atom = String.to_existing_atom(status)
    Enum.filter(history, &(&1.status == status_atom))
  end
end
