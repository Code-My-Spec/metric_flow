defmodule MetricFlowWeb.DashboardLive.Show do
  @moduledoc """
  LiveView for the "All Metrics" dashboard.

  Displays a single multi-series Vega-Lite line chart (all metrics as colored
  lines) plus an HTML data table with configurable granularity (day/week/month),
  date range picker, platform filter, and per-metric toggles. When no
  integrations are connected, renders an onboarding prompt. Unauthenticated
  users are redirected to `/users/log-in` by the router's authentication plug.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards

  # Known raw/additive metrics that always appear on the dashboard
  @known_raw_metrics ["clicks", "total_cost", "impressions", "revenue", "conversions"]

  # Derived metrics computed from raw component metrics
  @known_derived_metrics [
    %{name: "cpc", numerator: "total_cost", denominator: "clicks"},
    %{name: "ctr", numerator: "clicks", denominator: "impressions"},
    %{name: "roas", numerator: "revenue", denominator: "total_cost"}
  ]

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
      active_account_type={assigns[:active_account_type]}
    >
    <div class="px-4 py-8">
      <div class="mb-8 flex items-start justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold">All Metrics</h1>
          <p class="mt-1 text-base-content/60">
            Your complete marketing and financial picture
          </p>
        </div>
        <button
          phx-click="open_ai_chat"
          data-role="open-ai-chat"
          class="btn btn-ghost btn-sm flex-shrink-0"
        >
          AI Chat
        </button>
      </div>

      <%!-- Inline AI chat panel --%>
      <div
        :if={@chat_panel_open}
        data-role="ai-chat-interface"
        class="mf-card p-5 mb-6"
      >
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-base font-semibold">AI Chat</h3>
          <button
            phx-click="close_ai_chat"
            data-role="close-chat-panel"
            aria-label="Close AI Chat"
            class="btn btn-ghost btn-xs"
          >
            ✕
          </button>
        </div>
        <p class="text-sm text-base-content/60 mb-3">
          Ask questions about your metrics and get AI-powered insights.
        </p>
        <.link navigate={~p"/app/chat"} class="btn btn-primary btn-sm">
          Open Full AI Chat
        </.link>
      </div>

      <div :if={not @has_integrations} data-role="onboarding-prompt" class="mf-card p-8 text-center">
        <h2 class="text-xl font-semibold">Connect Your Platforms</h2>
        <p class="mt-2 text-base-content/60">
          Connect your marketing and financial platforms to start seeing unified metrics, AI insights, and recommendations.
        </p>
        <a href="/app/integrations" class="btn btn-primary mt-6">
          Connect Integrations
        </a>
      </div>

      <div :if={@has_integrations} data-role="metrics-dashboard">
        <%!-- Filter controls --%>
        <div class="flex items-center gap-4 mb-4 flex-wrap">
          <%!-- Platform filter --%>
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
        </div>

        <%!-- Custom date range picker --%>
        <div :if={@selected_date_range == :custom} data-role="custom-date-picker" class="flex items-center gap-3 mb-4">
          <form phx-change="update_custom_dates" class="flex items-center gap-3">
            <label class="text-sm text-base-content/60">From</label>
            <input
              type="date"
              name="start_date"
              value={@custom_start_date}
              class="input input-sm input-bordered bg-base-200"
            />
            <label class="text-sm text-base-content/60">To</label>
            <input
              type="date"
              name="end_date"
              value={@custom_end_date}
              class="input input-sm input-bordered bg-base-200"
            />
          </form>
        </div>

        <%!-- Date range display + granularity toggle --%>
        <div class="flex items-center justify-between mb-4 flex-wrap gap-2">
          <div data-role="date-range" class="text-sm text-base-content/60">
            {render_date_range(@dashboard_data.applied_filters[:date_range])}
          </div>

          <div data-role="granularity-toggle" class="flex items-center gap-1">
            <span class="text-xs text-base-content/60 mr-1">Group by:</span>
            <button
              :for={g <- [:day, :week, :month]}
              phx-click="set_granularity"
              phx-value-granularity={g}
              class={["btn btn-xs", if(@granularity == g, do: "btn-primary", else: "btn-ghost")]}
            >
              {granularity_label(g)}
            </button>
          </div>
        </div>

        <%!-- Metric toggles --%>
        <div data-role="metric-toggles" class="flex items-center gap-1 flex-wrap mb-6">
          <button
            :for={name <- @all_metric_names}
            phx-click="toggle_metric"
            phx-value-metric={name}
            class={["btn btn-xs", if(MapSet.member?(@visible_metrics, name), do: "btn-primary", else: "btn-ghost")]}
          >
            {name}
          </button>
        </div>

        <%!-- Multi-series chart --%>
        <div data-role="multi-series-chart" class="mf-card p-4 mb-4">
          <div class="flex items-center justify-between mb-3">
            <h3 class="text-base font-semibold">Metrics Over Time</h3>
            <button
              phx-click="show_ai_insights"
              phx-value-metric="All Metrics"
              data-role="ai-info-button"
              class="btn btn-ghost btn-xs"
              aria-label="View AI insights"
            >
              AI Insights
            </button>
          </div>
          <div
            :if={@chart_spec != nil}
            data-role="vega-lite-chart"
            phx-hook="VegaLite"
            phx-update="ignore"
            data-spec={Jason.encode!(@chart_spec)}
            id="multi-series-chart"
            style="width: 100%"
          >
          </div>
          <p
            :if={@chart_spec == nil}
            class="text-base-content/60 text-center py-8"
          >
            No metric data available for the selected filters.
          </p>
        </div>

        <%!-- Data table --%>
        <div data-role="data-table" class="mf-card p-4 mt-4 overflow-x-auto">
          <h3 class="text-base font-semibold mb-3">{granularity_label(@granularity)} Data</h3>
          <table :if={@table_rows != []} class="table table-sm table-zebra w-full">
            <thead>
              <tr>
                <th>{granularity_label(@granularity)}</th>
                <th :for={name <- @visible_metric_names}>{name}</th>
              </tr>
            </thead>
            <tbody>
              <tr :for={row <- @table_rows}>
                <td class="font-medium">{row.period}</td>
                <td :for={name <- @visible_metric_names}>
                  {format_number(row.values[name])}
                </td>
              </tr>
            </tbody>
          </table>
          <p :if={@table_rows == []} class="text-base-content/60 text-center py-4">
            No data to display.
          </p>
        </div>

        <%!-- Summary stats --%>
        <div data-role="summary-stats" class="grid grid-cols-2 sm:grid-cols-4 gap-4 mt-4">
          <div
            :for={stat <- visible_summary_stats(@dashboard_data.summary_stats, @visible_metrics)}
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
            <button
              phx-click="show_ai_insights"
              phx-value-metric={stat.metric_name}
              data-role="ai-info-button"
              class="btn btn-ghost btn-xs mt-2 w-full"
              aria-label={"View AI insights for #{stat.metric_name}"}
            >
              AI Insights
            </button>
          </div>
        </div>

        <div
          :if={Enum.empty?(visible_summary_stats(@dashboard_data.summary_stats, @visible_metrics))}
          class="mf-card p-6 text-center mt-4"
        >
          <p class="text-base-content/60">No metrics match the selected filters.</p>
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
            Visit <.link navigate={~p"/app/insights"} class="link link-primary">AI Insights</.link>
            for detailed recommendations.
          </p>
        </div>

        <%!-- Semantic difference footnote --%>
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
          |> assign(:chat_panel_open, false)
          |> assign(:page_title, "All Metrics")

        {:ok, socket}

      true ->
        available_date_ranges = Dashboards.available_date_ranges()
        default_range = Dashboards.default_date_range()

        {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, date_range: default_range)
        dashboard_data = enrich_with_known_metrics(dashboard_data)

        all_metric_names = Enum.map(dashboard_data.time_series, & &1.metric_name) |> Enum.sort()
        visible_metrics = MapSet.new(all_metric_names)

        {default_start, default_end} = default_range

        socket =
          socket
          |> assign(:has_integrations, true)
          |> assign(:dashboard_data, dashboard_data)
          |> assign(:available_date_ranges, available_date_ranges)
          |> assign(:selected_platform, nil)
          |> assign(:selected_date_range, :last_30_days)
          |> assign(:granularity, :day)
          |> assign(:custom_start_date, Date.to_iso8601(default_start))
          |> assign(:custom_end_date, Date.to_iso8601(default_end))
          |> assign(:all_metric_names, all_metric_names)
          |> assign(:visible_metrics, visible_metrics)
          |> assign(:ai_panel_open, false)
          |> assign(:ai_panel_metric, nil)
          |> assign(:chat_panel_open, false)
          |> assign(:page_title, "All Metrics")
          |> rebuild_chart_and_table()

        {:ok, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter_platform", %{"platform" => "all"}, socket) do
    socket = reload_dashboard_data(socket, selected_platform: nil)
    {:noreply, socket}
  end

  def handle_event("filter_platform", %{"platform" => platform_key}, socket) do
    platform = String.to_existing_atom(platform_key)
    socket = reload_dashboard_data(socket, selected_platform: platform)
    {:noreply, socket}
  end

  def handle_event("filter_date_range", %{"range" => "custom"}, socket) do
    # Switch to custom mode — use current custom dates to reload
    start_date = Date.from_iso8601!(socket.assigns.custom_start_date)
    end_date = Date.from_iso8601!(socket.assigns.custom_end_date)

    socket =
      socket
      |> assign(:selected_date_range, :custom)
      |> reload_dashboard_data_with_range({start_date, end_date})

    {:noreply, socket}
  end

  def handle_event("filter_date_range", %{"range" => range_key}, socket) do
    range_atom = String.to_existing_atom(range_key)
    socket = reload_dashboard_data(socket, selected_date_range: range_atom)
    {:noreply, socket}
  end

  def handle_event("update_custom_dates", %{"start_date" => start_str, "end_date" => end_str}, socket) do
    with {:ok, start_date} <- Date.from_iso8601(start_str),
         {:ok, end_date} <- Date.from_iso8601(end_str),
         true <- Date.compare(start_date, end_date) != :gt do
      socket =
        socket
        |> assign(:custom_start_date, start_str)
        |> assign(:custom_end_date, end_str)
        |> reload_dashboard_data_with_range({start_date, end_date})

      {:noreply, socket}
    else
      _ ->
        # Invalid dates — just update the input values, don't reload
        {:noreply,
         socket
         |> assign(:custom_start_date, start_str)
         |> assign(:custom_end_date, end_str)}
    end
  end

  def handle_event("set_granularity", %{"granularity" => granularity}, socket) do
    granularity = String.to_existing_atom(granularity)

    socket =
      socket
      |> assign(:granularity, granularity)
      |> rebuild_chart_and_table()

    {:noreply, socket}
  end

  def handle_event("toggle_metric", %{"metric" => metric_name}, socket) do
    visible = socket.assigns.visible_metrics

    visible =
      if MapSet.member?(visible, metric_name) do
        MapSet.delete(visible, metric_name)
      else
        MapSet.put(visible, metric_name)
      end

    socket =
      socket
      |> assign(:visible_metrics, visible)
      |> rebuild_chart_and_table()

    {:noreply, socket}
  end

  def handle_event("show_ai_insights", %{"metric" => metric_name}, socket) do
    {:noreply, socket |> assign(:ai_panel_open, true) |> assign(:ai_panel_metric, metric_name)}
  end

  def handle_event("hide_ai_insights", _params, socket) do
    {:noreply, socket |> assign(:ai_panel_open, false)}
  end

  def handle_event("open_ai_chat", _params, socket) do
    {:noreply, assign(socket, :chat_panel_open, true)}
  end

  def handle_event("close_ai_chat", _params, socket) do
    {:noreply, assign(socket, :chat_panel_open, false)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers — data loading
  # ---------------------------------------------------------------------------

  defp reload_dashboard_data(socket, overrides) do
    selected_platform = Keyword.get(overrides, :selected_platform, socket.assigns.selected_platform)
    selected_date_range = Keyword.get(overrides, :selected_date_range, socket.assigns.selected_date_range)

    opts =
      build_filter_opts(selected_platform, selected_date_range, socket.assigns.available_date_ranges)

    do_reload(socket, opts, selected_platform, selected_date_range)
  end

  defp reload_dashboard_data_with_range(socket, {start_date, end_date}) do
    opts =
      []
      |> maybe_put(:platform, socket.assigns.selected_platform)
      |> Keyword.put(:date_range, {start_date, end_date})

    do_reload(socket, opts, socket.assigns.selected_platform, :custom)
  end

  defp do_reload(socket, opts, selected_platform, selected_date_range) do
    scope = socket.assigns.current_scope

    {:ok, dashboard_data} = Dashboards.get_dashboard_data(scope, opts)
    dashboard_data = enrich_with_known_metrics(dashboard_data)

    all_metric_names = Enum.map(dashboard_data.time_series, & &1.metric_name) |> Enum.sort()

    visible_metrics =
      socket.assigns.visible_metrics
      |> MapSet.intersection(MapSet.new(all_metric_names))
      |> MapSet.union(MapSet.difference(MapSet.new(all_metric_names), MapSet.new(socket.assigns.all_metric_names)))

    socket
    |> assign(:dashboard_data, dashboard_data)
    |> assign(:selected_platform, selected_platform)
    |> assign(:selected_date_range, selected_date_range)
    |> assign(:all_metric_names, all_metric_names)
    |> assign(:visible_metrics, visible_metrics)
    |> rebuild_chart_and_table()
  end

  # ---------------------------------------------------------------------------
  # Private helpers — chart & table building
  # ---------------------------------------------------------------------------

  defp rebuild_chart_and_table(socket) do
    visible = socket.assigns.visible_metrics
    granularity = socket.assigns.granularity
    dashboard_data = socket.assigns.dashboard_data

    visible_ts =
      Enum.filter(dashboard_data.time_series, fn entry ->
        MapSet.member?(visible, entry.metric_name)
      end)

    visible_metric_names =
      visible_ts
      |> Enum.reject(fn entry -> entry.data == [] end)
      |> Enum.map(& &1.metric_name)
      |> Enum.sort()

    aggregated_ts = aggregate_time_series(visible_ts, granularity)

    chart_spec =
      if aggregated_ts != [] do
        Dashboards.build_multi_series_chart_spec("Metrics Over Time", aggregated_ts)
      else
        nil
      end

    table_rows = build_table_rows(visible_ts, granularity)

    socket
    |> assign(:chart_spec, chart_spec)
    |> assign(:table_rows, table_rows)
    |> assign(:visible_metric_names, visible_metric_names)
    |> push_chart_update(chart_spec)
  end

  defp aggregate_time_series(time_series, :day), do: time_series

  defp aggregate_time_series(time_series, granularity) do
    Enum.map(time_series, fn %{metric_name: metric_name, data: data} ->
      aggregated_data =
        data
        |> Enum.group_by(fn %{date: date} -> period_start_date(date, granularity) end)
        |> Enum.map(fn {period_date, points} ->
          %{date: period_date, value: Enum.reduce(points, 0.0, &(&1.value + &2))}
        end)
        |> Enum.sort_by(& &1.date, Date)

      %{metric_name: metric_name, data: aggregated_data}
    end)
  end

  defp period_start_date(date, :week) do
    day_of_week = Date.day_of_week(date)
    Date.add(date, -(day_of_week - 1))
  end

  defp period_start_date(date, :month) do
    Date.new!(date.year, date.month, 1)
  end

  defp push_chart_update(socket, nil), do: socket

  defp push_chart_update(socket, chart_spec) do
    push_event(socket, "update-chart", %{spec: chart_spec})
  end

  defp build_table_rows(time_series, granularity) do
    time_series
    |> Enum.flat_map(fn %{metric_name: metric_name, data: data} ->
      Enum.map(data, fn %{date: date, value: value} ->
        period = date_to_period(date, granularity)
        {period, metric_name, value}
      end)
    end)
    |> Enum.group_by(fn {period, _name, _val} -> period end)
    |> Enum.map(fn {period, entries} ->
      values =
        Enum.reduce(entries, %{}, fn {_period, name, val}, acc ->
          Map.update(acc, name, val, &(&1 + val))
        end)

      %{period: period, values: values}
    end)
    |> Enum.sort_by(& &1.period)
  end

  defp date_to_period(date, :day), do: Date.to_iso8601(date)

  defp date_to_period(date, :week) do
    # Monday of the week
    day_of_week = Date.day_of_week(date)
    monday = Date.add(date, -(day_of_week - 1))
    "W #{Date.to_iso8601(monday)}"
  end

  defp date_to_period(date, :month), do: Calendar.strftime(date, "%Y-%m")

  # ---------------------------------------------------------------------------
  # Private helpers — filters
  # ---------------------------------------------------------------------------

  defp build_filter_opts(platform, date_range_key, available_date_ranges) do
    date_range_tuple = resolve_date_range(date_range_key, available_date_ranges)

    []
    |> maybe_put(:platform, platform)
    |> maybe_put_date_range(date_range_tuple)
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

  # ---------------------------------------------------------------------------
  # Private helpers — formatting
  # ---------------------------------------------------------------------------

  defp render_date_range({start_date, end_date}) do
    "Showing #{Date.to_iso8601(start_date)} – #{Date.to_iso8601(end_date)} (today excluded — incomplete day)"
  end

  defp render_date_range(nil) do
    "Showing all available data (today excluded — incomplete day)"
  end

  defp platform_display_name(platform) when is_atom(platform) do
    platform
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp granularity_label(:day), do: "Daily"
  defp granularity_label(:week), do: "Weekly"
  defp granularity_label(:month), do: "Monthly"

  defp format_number(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 1)
  end

  defp format_number(value) when is_integer(value) do
    Integer.to_string(value)
  end

  defp format_number(nil), do: "–"

  defp visible_summary_stats(summary_stats, visible_metrics) do
    Enum.filter(summary_stats, fn stat ->
      MapSet.member?(visible_metrics, stat.metric_name)
    end)
  end

  # ---------------------------------------------------------------------------
  # Known metrics enrichment
  # ---------------------------------------------------------------------------

  defp enrich_with_known_metrics(dashboard_data) do
    existing_stat_names = MapSet.new(Enum.map(dashboard_data.summary_stats, & &1.metric_name))

    raw_zero_stats =
      @known_raw_metrics
      |> Enum.reject(&MapSet.member?(existing_stat_names, &1))
      |> Enum.map(&zero_stat_entry/1)

    all_raw_stats = dashboard_data.summary_stats ++ raw_zero_stats

    raw_sums = Map.new(all_raw_stats, fn s -> {s.metric_name, s.stats.sum} end)

    derived_stats =
      Enum.map(@known_derived_metrics, fn %{name: name, numerator: num, denominator: den} ->
        num_val = Map.get(raw_sums, num, 0.0)
        den_val = Map.get(raw_sums, den, 0.0)
        value = safe_divide(num_val, den_val)
        %{metric_name: name, stats: %{sum: value, avg: value, min: value, max: value, count: 0}}
      end)

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
end
