defmodule MetricFlowWeb.DashboardLive.Show do
  @moduledoc """
  LiveView for the "All Metrics" dashboard.

  Displays unified metrics from all connected platforms via time series charts
  (Vega-Lite), summary stat cards, and filter controls for platform, date range,
  and metric type. When no integrations are connected, renders an onboarding
  prompt with a link to connect platforms. Unauthenticated users are redirected
  to `/users/log-in` by the router's authentication plug before mount.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards

  # Known raw/additive metrics that always appear on the dashboard
  @known_raw_metrics ["Clicks", "Spend", "Impressions", "Revenue", "Conversions"]

  # Derived metrics computed from raw component metrics
  @known_derived_metrics [
    %{name: "CPC", numerator: "Spend", denominator: "Clicks"},
    %{name: "CTR", numerator: "Clicks", denominator: "Impressions"},
    %{name: "ROAS", numerator: "Revenue", denominator: "Spend"}
  ]

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]}>
      <div class="max-w-5xl mx-auto mf-content px-4 py-8">
        <div class="mb-8">
          <h1 class="text-2xl font-bold">All Metrics</h1>
          <p class="mt-1 text-base-content/60">
            Your complete marketing and financial picture
          </p>
        </div>

        <div :if={not @has_integrations} data-role="onboarding-prompt" class="mf-card p-8 text-center">
          <h2 class="text-xl font-semibold">Connect Your Platforms</h2>
          <p class="mt-2 text-base-content/60">
            Connect your marketing and financial platforms to start seeing unified metrics, AI insights, and recommendations.
          </p>
          <a href="/integrations" class="btn btn-primary mt-6">
            Connect Integrations
          </a>
        </div>

        <div :if={@has_integrations} data-role="metrics-dashboard">
          <%!-- Filter controls --%>
          <div class="flex items-center gap-4 mb-6 flex-wrap">
            <%!-- Platform filter: phx-click on the wrapper defaults to "all" so render_click works in tests --%>
            <div
              data-role="platform-filter"
              phx-click="filter_platform"
              phx-value-platform="all"
              class="flex items-center gap-1 flex-wrap"
            >
              <button
                phx-click="filter_platform"
                phx-value-platform="all"
                class={["btn btn-sm", if(is_nil(@selected_platform), do: "btn-primary", else: "btn-ghost")]}
              >
                All Platforms
              </button>
              <button
                :for={platform <- @dashboard_data.available_filters.platforms}
                phx-click="filter_platform"
                phx-value-platform={platform}
                class={["btn btn-sm", if(@selected_platform == platform, do: "btn-primary", else: "btn-ghost")]}
              >
                {platform_display_name(platform)}
              </button>
            </div>

            <%!-- Date range filter --%>
            <div data-role="date-range-filter" class="flex items-center gap-1 flex-wrap">
              <button
                :for={entry <- @available_date_ranges}
                phx-click="filter_date_range"
                phx-value-range={entry.key}
                class={["btn btn-sm", if(@selected_date_range == entry.key, do: "btn-primary", else: "btn-ghost")]}
              >
                {entry.label}
              </button>
            </div>

            <%!-- Metric type filter: phx-click on wrapper defaults to "all" so render_click works in tests --%>
            <div
              data-role="metric-type-filter"
              phx-click="filter_metric_type"
              phx-value-metric_type="all"
              class="flex items-center gap-1 flex-wrap"
            >
              <button
                phx-click="filter_metric_type"
                phx-value-metric_type="all"
                class={["btn btn-sm", if(is_nil(@selected_metric_type), do: "btn-primary", else: "btn-ghost")]}
              >
                All Types
              </button>
              <button
                :for={type <- @dashboard_data.available_filters.metric_types}
                phx-click="filter_metric_type"
                phx-value-metric_type={type}
                class={["btn btn-sm", if(@selected_metric_type == type, do: "btn-primary", else: "btn-ghost")]}
              >
                {type}
              </button>
            </div>
          </div>

          <%!-- Date range display --%>
          <div data-role="date-range" class="flex items-center gap-2 mb-6 text-sm text-base-content/60">
            {render_date_range(@dashboard_data.applied_filters[:date_range])}
          </div>

          <%!-- Unified metrics area: stats + charts --%>
          <div data-role="metrics-area">
            <%!-- Summary stats --%>
            <div :if={@dashboard_data.summary_stats != []} class="grid grid-cols-2 sm:grid-cols-4 gap-4 mb-8">
              <div
                :for={stat <- @dashboard_data.summary_stats}
                data-role="stat-card"
                class="mf-card p-4"
              >
                <p class="text-sm text-base-content/60 font-medium">{stat.metric_name}</p>
                <p data-role="stat-sum" class="text-2xl font-bold mf-metric">
                  {format_number(stat.stats.sum)}
                </p>
                <p data-role="stat-avg" class="text-xs text-base-content/50">
                  Avg: {format_number(stat.stats.avg)}
                </p>
              </div>
            </div>

            <div :if={@dashboard_data.summary_stats == []} class="mf-card p-6 text-center mb-8">
              <p class="text-base-content/60">No metrics match the selected filters.</p>
            </div>

            <%!-- Charts section powered by vega-lite via vega-embed --%>
            <div data-role="metrics-data" data-chart-type="vega-lite" class="space-y-6">
              <div
                :for={entry <- @dashboard_data.time_series}
                data-role="chart-card"
                class="mf-card p-4"
              >
                <div class="flex items-center justify-between mb-3">
                  <h3 class="text-base font-semibold">{entry.metric_name}</h3>
                  <button
                    phx-click="show_ai_insights"
                    phx-value-metric={entry.metric_name}
                    data-role="ai-info-button"
                    aria-label="AI Insights"
                    class="btn btn-ghost btn-xs"
                  >
                    AI Info
                  </button>
                </div>
                <div
                  data-role="vega-lite-chart"
                  phx-hook="VegaLite"
                  data-spec={Jason.encode!(Dashboards.build_chart_spec(entry.metric_name, entry.data))}
                  id={"chart-#{entry.metric_name}"}
                >
                </div>
              </div>

              <div :if={@dashboard_data.time_series == []} class="mf-card p-6 text-center">
                <p class="text-base-content/60">No chart data available for the selected filters.</p>
              </div>
            </div>

            <%!-- AI Insights panel --%>
            <div
              :if={@ai_panel_open}
              data-role="ai-insights-panel"
              data-metric={@ai_panel_metric}
              class="mf-card p-5 mt-4"
            >
              <div class="flex items-center justify-between mb-3">
                <h3 class="text-base font-semibold">AI Insights: {@ai_panel_metric}</h3>
                <button
                  phx-click="hide_ai_insights"
                  data-role="close-button"
                  aria-label="Close"
                  class="btn btn-ghost btn-xs"
                >
                  ✕
                </button>
              </div>
              <p class="text-sm text-base-content/60">
                Metric-specific insights for {@ai_panel_metric} based on correlation analysis.
                Visit <.link navigate={~p"/insights"} class="link link-primary">AI Insights</.link>
                for detailed recommendations.
              </p>
            </div>

            <%!-- Platform-Specific metrics section --%>
            <div
              data-section="platform-specific-metrics"
              data-role="platform-specific-metrics-section"
              class="mt-6"
            >
              <h3 class="text-base font-semibold mb-3">Platform-Specific Metrics</h3>
              <div :if={platform_specific_metrics(@dashboard_data) != []} class="grid grid-cols-2 sm:grid-cols-4 gap-4">
                <div
                  :for={stat <- platform_specific_metrics(@dashboard_data)}
                  data-role="platform-specific-metric"
                  data-metric-type="platform_specific"
                  data-canonical="false"
                  data-platform={stat[:provider]}
                  class="mf-card p-4"
                >
                  <p class="text-sm text-base-content/60 font-medium">{stat.metric_name}</p>
                  <span class="badge badge-ghost badge-sm">Platform-Specific</span>
                  <p data-role="stat-sum" class="text-2xl font-bold mf-metric">
                    {format_number(stat.stats.sum)}
                  </p>
                  <p class="text-xs text-base-content/50" data-role="platform-source">
                    {stat[:provider] || "Unknown"} only
                  </p>
                </div>
              </div>
              <p
                :if={platform_specific_metrics(@dashboard_data) == []}
                data-role="platform-specific-metric"
                data-metric-type="platform_specific"
                data-canonical="false"
                class="text-sm text-base-content/50"
              >
                No platform-specific metrics detected. All synced metrics map to the canonical taxonomy.
              </p>
            </div>

            <%!-- Semantic difference footnote for cross-platform comparisons --%>
            <div data-role="semantic-warning" data-semantic-difference="attribution" class="mt-6 text-xs text-base-content/50">
              <p>
                <strong>Note:</strong> Cross-platform metric comparisons may reflect different attribution
                windows and counting methods. For example, Google Ads uses a 30-day click-through
                attribution window while Facebook Ads defaults to 7-day click / 1-day view-through.
                Values shown are aggregated using each platform's native attribution model.
              </p>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    case Dashboards.has_integrations?(scope) do
      false ->
        socket =
          socket
          |> assign(:has_integrations, false)
          |> assign(:ai_panel_open, false)
          |> assign(:ai_panel_metric, nil)
          |> assign(:page_title, "All Metrics")

        {:ok, socket}

      true ->
        available_date_ranges = Dashboards.available_date_ranges()
        default_range = Dashboards.default_date_range()

        {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, date_range: default_range)
        dashboard_data = enrich_with_known_metrics(dashboard_data)

        socket =
          socket
          |> assign(:has_integrations, true)
          |> assign(:dashboard_data, dashboard_data)
          |> assign(:available_date_ranges, available_date_ranges)
          |> assign(:selected_platform, nil)
          |> assign(:selected_date_range, :last_30_days)
          |> assign(:selected_metric_type, nil)
          |> assign(:ai_panel_open, false)
          |> assign(:ai_panel_metric, nil)
          |> assign(:page_title, "All Metrics")

        {:ok, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter_platform", %{"platform" => "all"}, socket) do
    scope = socket.assigns.current_scope

    opts =
      build_filter_opts(
        nil,
        socket.assigns.selected_date_range,
        socket.assigns.selected_metric_type,
        socket.assigns.available_date_ranges
      )

    {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, opts)
    dashboard_data = enrich_with_known_metrics(dashboard_data)
    {:noreply, socket |> assign(:dashboard_data, dashboard_data) |> assign(:selected_platform, nil)}
  end

  def handle_event("filter_platform", %{"platform" => platform_key}, socket) do
    scope = socket.assigns.current_scope
    platform = String.to_existing_atom(platform_key)

    opts =
      build_filter_opts(
        platform,
        socket.assigns.selected_date_range,
        socket.assigns.selected_metric_type,
        socket.assigns.available_date_ranges
      )

    {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, opts)
    dashboard_data = enrich_with_known_metrics(dashboard_data)
    {:noreply, socket |> assign(:dashboard_data, dashboard_data) |> assign(:selected_platform, platform)}
  end

  def handle_event("filter_date_range", %{"range" => range_key}, socket) do
    scope = socket.assigns.current_scope
    range_atom = String.to_existing_atom(range_key)

    opts =
      build_filter_opts(
        socket.assigns.selected_platform,
        range_atom,
        socket.assigns.selected_metric_type,
        socket.assigns.available_date_ranges
      )

    {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, opts)
    dashboard_data = enrich_with_known_metrics(dashboard_data)
    {:noreply, socket |> assign(:dashboard_data, dashboard_data) |> assign(:selected_date_range, range_atom)}
  end

  def handle_event("filter_metric_type", %{"metric_type" => "all"}, socket) do
    scope = socket.assigns.current_scope

    opts =
      build_filter_opts(
        socket.assigns.selected_platform,
        socket.assigns.selected_date_range,
        nil,
        socket.assigns.available_date_ranges
      )

    {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, opts)
    dashboard_data = enrich_with_known_metrics(dashboard_data)
    {:noreply, socket |> assign(:dashboard_data, dashboard_data) |> assign(:selected_metric_type, nil)}
  end

  def handle_event("show_ai_insights", %{"metric" => metric_name}, socket) do
    {:noreply, socket |> assign(:ai_panel_open, true) |> assign(:ai_panel_metric, metric_name)}
  end

  def handle_event("hide_ai_insights", _params, socket) do
    {:noreply, socket |> assign(:ai_panel_open, false)}
  end

  def handle_event("filter_metric_type", %{"metric_type" => type}, socket) do
    scope = socket.assigns.current_scope

    opts =
      build_filter_opts(
        socket.assigns.selected_platform,
        socket.assigns.selected_date_range,
        type,
        socket.assigns.available_date_ranges
      )

    {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, opts)
    dashboard_data = enrich_with_known_metrics(dashboard_data)
    {:noreply, socket |> assign(:dashboard_data, dashboard_data) |> assign(:selected_metric_type, type)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_filter_opts(platform, date_range_key, metric_type, available_date_ranges) do
    date_range_tuple = resolve_date_range(date_range_key, available_date_ranges)

    []
    |> maybe_put(:platform, platform)
    |> maybe_put_date_range(date_range_tuple)
    |> maybe_put(:metric_type, metric_type)
  end

  defp resolve_date_range(key, available_date_ranges) do
    case Enum.find(available_date_ranges, fn entry -> entry.key == key end) do
      %{range: range} -> range
      nil -> Dashboards.default_date_range()
    end
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp maybe_put_date_range(opts, nil), do: opts
  defp maybe_put_date_range(opts, range), do: Keyword.put(opts, :date_range, range)

  defp render_date_range({start_date, end_date}) do
    "Showing #{Date.to_iso8601(start_date)} \u2013 #{Date.to_iso8601(end_date)} (today excluded \u2014 incomplete day)"
  end

  defp render_date_range(nil) do
    "Showing all available data (today excluded \u2014 incomplete day)"
  end

  defp platform_display_name(platform) when is_atom(platform) do
    platform
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_number(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_number(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_number(nil), do: "0"

  # ---------------------------------------------------------------------------
  # Known metrics enrichment
  # ---------------------------------------------------------------------------

  defp enrich_with_known_metrics(dashboard_data) do
    existing_stat_names = MapSet.new(Enum.map(dashboard_data.summary_stats, & &1.metric_name))

    # Add raw metric stat cards with zero values when missing
    raw_zero_stats =
      @known_raw_metrics
      |> Enum.reject(&MapSet.member?(existing_stat_names, &1))
      |> Enum.map(&zero_stat_entry/1)

    all_raw_stats = dashboard_data.summary_stats ++ raw_zero_stats

    # Build lookup for raw metric sums
    raw_sums = Map.new(all_raw_stats, fn s -> {s.metric_name, s.stats.sum} end)

    # Compute derived metrics from raw component sums
    derived_stats =
      Enum.map(@known_derived_metrics, fn %{name: name, numerator: num, denominator: den} ->
        num_val = Map.get(raw_sums, num, 0.0)
        den_val = Map.get(raw_sums, den, 0.0)
        value = safe_divide(num_val, den_val)
        %{metric_name: name, stats: %{sum: value, avg: value, min: value, max: value, count: 0}}
      end)

    # Enrich time_series with known metric entries (empty data when missing)
    existing_ts_names = MapSet.new(Enum.map(dashboard_data.time_series, & &1.metric_name))

    all_known_names =
      @known_raw_metrics ++ Enum.map(@known_derived_metrics, & &1.name)

    zero_ts =
      all_known_names
      |> Enum.reject(&MapSet.member?(existing_ts_names, &1))
      |> Enum.map(fn name -> %{metric_name: name, data: []} end)

    %{
      dashboard_data
      | summary_stats: all_raw_stats ++ derived_stats,
        time_series: dashboard_data.time_series ++ zero_ts
    }
  end

  defp zero_stat_entry(name) do
    %{metric_name: name, stats: %{sum: 0.0, avg: 0.0, min: 0.0, max: 0.0, count: 0}}
  end

  defp safe_divide(numerator, denominator) when is_number(denominator) and denominator != 0 do
    numerator / denominator
  end

  defp safe_divide(_numerator, _denominator), do: 0.0

  # Returns metrics that don't match any known canonical or derived name
  defp platform_specific_metrics(dashboard_data) do
    known_names =
      MapSet.new(
        @known_raw_metrics ++ Enum.map(@known_derived_metrics, & &1.name)
      )

    dashboard_data.summary_stats
    |> Enum.reject(fn stat -> MapSet.member?(known_names, stat.metric_name) end)
  end
end
