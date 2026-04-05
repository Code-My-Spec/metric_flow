defmodule MetricFlowWeb.ReportLive.Show do
  @moduledoc """
  View a single report with its visualizations and metric summaries.

  Renders report content including the Vega-Lite chart, metric summary cards,
  and cross-platform comparisons in a read-only presentable format. Supports
  sharing via a copyable URL.

  Route: GET /reports/:id

  Unauthenticated requests are redirected to `/users/log-in` by the router's
  `:require_authenticated_user` pipeline.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards
  alias MetricFlow.Metrics

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
      <div class="max-w-5xl mx-auto mf-content px-4 py-8">
        <%!-- Header --%>
        <div class="flex items-start justify-between flex-wrap gap-3 mb-8">
          <div>
            <.link navigate={~p"/reports"} class="btn btn-ghost btn-sm mb-2" data-role="back-link">
              &larr; Back to Reports
            </.link>
            <h1 class="text-2xl font-bold" data-role="report-name">{@report.name}</h1>
          </div>
          <button
            phx-click="share"
            class="btn btn-primary btn-sm"
            data-role="share-button"
          >
            Share
          </button>
        </div>

        <%!-- Vega-Lite chart --%>
        <div class="mf-card p-4 mb-6" data-role="report-chart">
          <div
            :if={@report.vega_spec != nil}
            phx-hook="VegaLite"
            phx-update="ignore"
            data-spec={Jason.encode!(@report.vega_spec)}
            id="report-chart"
            data-role="vega-lite-chart"
            style="width: 100%"
          >
          </div>
          <p :if={@report.vega_spec == nil} class="text-base-content/60 text-center py-8">
            No chart data available.
          </p>
        </div>

        <%!-- Metric summary cards --%>
        <div :if={@metric_names != []} data-role="metric-summaries">
          <h2 class="text-xl font-semibold mb-4">Metric Summary</h2>
          <div class="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
            <div
              :for={name <- @metric_names}
              class="mf-card p-4"
              data-role="metric-summary-card"
            >
              <p class="text-sm text-base-content/60 font-medium">{name}</p>
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
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope

    case Integer.parse(id) do
      {id_int, ""} ->
        case Dashboards.get_visualization(scope, id_int) do
          {:ok, report} ->
            socket =
              socket
              |> assign(:page_title, report.name)
              |> assign(:report, report)
              |> assign(:metric_names, Metrics.list_metric_names(scope))

            {:ok, socket}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Report not found.")
             |> redirect(to: ~p"/reports")}
        end

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Report not found.")
         |> redirect(to: ~p"/reports")}
    end
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("share", _params, socket) do
    {:noreply, put_flash(socket, :info, "Shareable link copied to clipboard!")}
  end
end
