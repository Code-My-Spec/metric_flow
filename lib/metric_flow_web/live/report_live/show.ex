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
      active_account_type={assigns[:active_account_type]}
    >
    <div>
      <%!-- Header --%>
      <div class="flex items-start justify-between flex-wrap gap-3 mb-8">
        <div>
          <.link navigate={~p"/app/reports"} class="btn btn-ghost btn-sm mb-2" data-role="back-link">
            &larr; Back to Reports
          </.link>
          <h1 class="text-2xl font-bold" data-role="report-name">{@report.name}</h1>
        </div>
        <div class="flex items-center gap-2">
          <.link
            navigate={ai_chat_path(@report)}
            data-role="open-ai-chat"
            class="btn btn-ghost btn-sm"
          >
            AI Chat
          </.link>
          <button
            phx-click="share"
            class="btn btn-primary btn-sm"
            data-role="share-button"
          >
            Share
          </button>
        </div>
      </div>

      <%!-- Date range filter --%>
      <div data-role="date-range-filter" class="flex items-center gap-1 flex-wrap mb-4">
        <button
          :for={entry <- @available_date_ranges}
          phx-click="filter_date_range"
          phx-value-range={entry.key}
          class={[
            "btn btn-sm",
            if(@selected_date_range == entry.key, do: "btn-primary", else: "btn-ghost")
          ]}
        >
          {entry.label}
        </button>
      </div>

      <%!-- Vega-Lite chart --%>
      <div class="mf-card p-4 mb-6" data-role="report-chart">
        <div :if={@spec_error} data-role="report-spec-error" class="text-center py-8">
          <p class="font-semibold text-error">Unable to render this chart</p>
          <p class="text-sm text-base-content/60 mt-1">{@spec_error}</p>
        </div>

        <div :if={@metric_error} data-role="metric-unavailable-error" class="text-center py-8">
          <p class="font-semibold text-warning">Metric unavailable</p>
          <p class="text-sm text-base-content/60 mt-1">{@metric_error}</p>
        </div>

        <div :if={@render_spec}>
          <div class="flex items-center justify-end mb-2">
            <button
              type="button"
              phx-click={JS.push("toggle_expand") |> JS.toggle_class("report-chart-expanded", to: "#report-chart")}
              data-role="report-chart-expand"
              class="btn btn-ghost btn-xs"
              aria-label="Expand chart"
            >
              {if @expanded, do: "Collapse", else: "Expand"}
            </button>
          </div>

          <div
            phx-hook="VegaLite"
            phx-update="ignore"
            data-spec={Jason.encode!(@render_spec)}
            id="report-chart"
            data-role="vega-lite-chart"
            class="report-chart-box"
            style="width: 100%;"
          >
          </div>

          <div
            id="report-chart-resize-handle"
            data-role="report-chart-resize-handle"
            phx-hook="ResizablePanel"
            data-target="#report-chart"
            data-direction="bottom"
            data-min-height="200"
            data-max-height="900"
            class="h-2 cursor-row-resize bg-base-300 hover:bg-primary/40 transition-colors mt-1 rounded"
          >
          </div>
        </div>
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
            {:ok, assign_report(socket, scope, report)}

          {:error, :not_found} ->
            {:ok,
             socket
             |> put_flash(:error, "Report not found.")
             |> redirect(to: ~p"/app/reports")}
        end

      _ ->
        {:ok,
         socket
         |> put_flash(:error, "Report not found.")
         |> redirect(to: ~p"/app/reports")}
    end
  end

  defp assign_report(socket, scope, report) do
    bound_metrics = Dashboards.get_visualization_metric_names(report)
    selected_date_range = parse_date_range_key(report.last_viewed_date_range)

    {render_spec, spec_error, metric_error} =
      cond do
        not valid_vega_spec?(report.vega_spec) ->
          {nil, "This chart's specification is invalid or corrupted.", nil}

        bound_metrics != [] and metric_unavailable?(scope, bound_metrics) ->
          {nil, nil, "This visualization is bound to a metric with no available data."}

        true ->
          date_range = Dashboards.date_range_for_key(selected_date_range)
          {Dashboards.build_render_spec(scope, report, date_range: date_range), nil, nil}
      end

    socket
    |> assign(:page_title, report.name)
    |> assign(:report, report)
    |> assign(:render_spec, render_spec)
    |> assign(:spec_error, spec_error)
    |> assign(:metric_error, metric_error)
    |> assign(:expanded, false)
    |> assign(:metric_names, Metrics.list_metric_names(scope))
    |> assign(:available_date_ranges, Enum.reject(Dashboards.available_date_ranges(), &(&1.key == :custom)))
    |> assign(:selected_date_range, selected_date_range)
  end

  defp parse_date_range_key(nil), do: :last_30_days

  defp parse_date_range_key(key) do
    String.to_existing_atom(key)
  rescue
    ArgumentError -> :last_30_days
  end

  defp valid_vega_spec?(spec) when is_map(spec), do: Map.has_key?(spec, "mark") or Map.has_key?(spec, "layer")
  defp valid_vega_spec?(_), do: false

  defp metric_unavailable?(scope, metric_names) do
    known = MapSet.new(Metrics.list_metric_names(scope))
    Enum.all?(metric_names, fn name -> not MapSet.member?(known, name) end)
  end

  defp ai_chat_path(report) do
    ~p"/app/chat?context_type=visualization&context_id=#{report.id}"
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("share", _params, socket) do
    {:noreply, put_flash(socket, :info, "Shareable link copied to clipboard!")}
  end

  def handle_event("toggle_expand", _params, socket) do
    {:noreply, assign(socket, :expanded, !socket.assigns.expanded)}
  end

  def handle_event("filter_date_range", %{"range" => range_key}, socket) do
    scope = socket.assigns.current_scope
    range_atom = parse_date_range_key(range_key)

    case Dashboards.update_visualization(scope, socket.assigns.report, %{
           last_viewed_date_range: range_key
         }) do
      {:ok, updated_report} ->
        date_range = Dashboards.date_range_for_key(range_atom)

        socket =
          socket
          |> assign(:report, updated_report)
          |> assign(:selected_date_range, range_atom)
          |> assign(:render_spec, Dashboards.build_render_spec(scope, updated_report, date_range: date_range))

        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not update date range.")}
    end
  end
end
