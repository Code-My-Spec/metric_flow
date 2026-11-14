defmodule MetricFlowWeb.DashboardLive.Components do
  @moduledoc """
  Function components shared by DashboardLive.Editor (building) and
  DashboardLive.Show (the read-only view page) -- the same widget card and
  platform-filter bar, so the two pages can't visually drift the way their
  query/render logic had (main's review at 76d8303: Show rendered a table
  widget as a line chart and had no platform-filter control at all).
  """

  use Phoenix.Component

  alias MetricFlow.Dashboards.A2ui

  attr :chart_id, :string, required: true
  attr :title, :string, required: true
  attr :chart_type, :string, default: nil
  attr :render, :any, required: true

  def widget_card(assigns) do
    ~H"""
    <div data-role="visualization-card" class="mf-card p-4">
      <div class="flex items-center gap-2 mb-2">
        <span class="font-semibold">{@title}</span>
        <span :if={@chart_type} class="badge badge-ghost badge-sm">{@chart_type}</span>
      </div>

      <div data-role="chart-preview" class={chart_preview_class(@render)}>
        <p :if={elem(@render, 0) == :stat} data-role="stat-tile-value" class="text-3xl font-bold">
          {elem(@render, 1)}
        </p>
        <div
          :if={elem(@render, 0) == :chart}
          id={@chart_id}
          data-role="echarts-chart"
          phx-hook="ECharts"
          phx-update="ignore"
          data-option={Jason.encode!(elem(@render, 1))}
          class="w-full h-full"
        >
        </div>
        <p
          :if={elem(@render, 0) == :no_data}
          data-role="no-data-message"
          class="text-sm text-base-content/60"
        >
          No data for this period
        </p>
        <table :if={elem(@render, 0) == :table} class="table table-sm w-full">
          <thead>
            <tr>
              <th>Date</th>
              <th>Value</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{date, value} <- elem(@render, 1)}>
              <td>{date}</td>
              <td>{value}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp chart_preview_class(render) do
    if elem(render, 0) == :table,
      do: "mt-2 bg-base-200 rounded p-2 overflow-x-auto",
      else: "mt-2 h-32 bg-base-200 rounded overflow-hidden flex items-center justify-center"
  end

  attr :available_platforms, :list, required: true
  attr :selected_platform, :any, default: nil

  def platform_filter(assigns) do
    ~H"""
    <div
      :if={@available_platforms != []}
      data-role="platform-filter"
      class="mf-card p-3 mb-6 flex items-center gap-2"
    >
      <span class="text-sm text-base-content/70">Platform</span>
      <button
        phx-click="filter_platform"
        phx-value-platform="all"
        class={["btn btn-sm", (is_nil(@selected_platform) && "btn-primary") || "btn-ghost"]}
      >
        All
      </button>
      <button
        :for={platform <- @available_platforms}
        phx-click="filter_platform"
        phx-value-platform={platform}
        class={["btn btn-sm", (@selected_platform == platform && "btn-primary") || "btn-ghost"]}
      >
        {A2ui.platform_display_name(platform)}
      </button>
    </div>
    """
  end
end
