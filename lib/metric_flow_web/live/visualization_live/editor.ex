defmodule MetricFlowWeb.VisualizationLive.Editor do
  @moduledoc """
  LiveView for creating and editing a standalone visualization.

  Authenticated users can build a named Vega-Lite chart from available metrics,
  preview it, and save it to their library. The resulting visualization may
  later be added to any dashboard via the Dashboard editor.

  Unauthenticated requests are redirected to `/users/log-in` by the router's
  `:require_authenticated_user` pipeline.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards
  alias MetricFlow.Dashboards.Visualization

  @chart_types ["line", "bar", "area"]

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
      <div class="max-w-3xl mx-auto px-4 py-8">
        <%!-- Page header --%>
        <div class="flex items-center justify-between flex-wrap gap-3 mb-6">
          <h1 class="text-2xl font-bold">
            {page_title_for(@live_action)}
          </h1>
          <div class="flex items-center gap-2">
            <button
              phx-click="save_visualization"
              data-role="save-visualization-btn"
              class="btn btn-primary btn-sm"
            >
              Save Visualization
            </button>
            <.link navigate="/dashboards" class="btn btn-ghost btn-sm">Cancel</.link>
          </div>
        </div>

        <%!-- Name field --%>
        <div class="form-control mb-4">
          <label class="label">
            <span class="label-text">Visualization Name</span>
          </label>
          <input
            type="text"
            name="name"
            value={@name}
            data-role="visualization-name-input"
            phx-change="validate_name"
            placeholder="My Visualization"
            class={["input input-bordered w-full", @name_error && "input-error"]}
          />
          <p :if={@name_error} class="text-sm text-error mt-1">
            {@name_error}
          </p>
        </div>

        <%!-- Metric selector --%>
        <div data-role="metric-selector" class="mf-card p-5 mb-4">
          <p class="font-semibold text-sm mb-3">Choose a Metric</p>
          <div data-role="metric-list" class="flex flex-wrap gap-2 max-h-40 overflow-y-auto">
            <button
              :for={metric <- @available_metrics}
              phx-click="select_metric"
              phx-value-metric={metric}
              class={[
                "btn btn-sm",
                @selected_metric == metric && "btn-primary",
                @selected_metric != metric && "btn-ghost"
              ]}
            >
              {metric}
            </button>
            <div :if={@available_metrics == []} data-role="no-metrics-available">
              <p class="text-sm text-base-content/60">
                No metrics available. Connect a platform to get started.
              </p>
              <.link navigate="/integrations" class="btn btn-ghost btn-sm mt-2">
                Go to Integrations
              </.link>
            </div>
          </div>
        </div>

        <%!-- Chart type selector --%>
        <div data-role="chart-type-selector" class="mf-card p-5 mb-4">
          <p class="font-semibold text-sm mb-3">Chart Type</p>
          <div class="flex items-center gap-2">
            <button
              :for={type <- @chart_types}
              phx-click="select_chart_type"
              phx-value-chart_type={type}
              class={[
                "btn btn-sm",
                @selected_chart_type == type && "btn-primary",
                @selected_chart_type != type && "btn-ghost"
              ]}
            >
              {String.capitalize(type)}
            </button>
          </div>
        </div>

        <%!-- Options row --%>
        <div class="flex items-center gap-4 mb-4">
          <button
            phx-click="toggle_shareable"
            data-role="toggle-shareable"
            class={[
              "btn btn-sm",
              @shareable && "btn-primary",
              !@shareable && "btn-ghost"
            ]}
          >
            Shareable
          </button>
          <span class="text-xs text-base-content/60">
            Let others add this visualization to their dashboards.
          </span>
        </div>

        <%!-- Chart preview --%>
        <div data-role="chart-preview-section" class="mf-card p-5 mb-4">
          <div class="flex items-center justify-between mb-4">
            <p class="font-semibold text-sm">Preview</p>
            <button
              phx-click="preview_chart"
              data-role="preview-chart-btn"
              disabled={is_nil(@selected_metric)}
              class={[
                "btn btn-outline btn-sm",
                is_nil(@selected_metric) && "btn-disabled"
              ]}
            >
              Preview Chart
            </button>
          </div>

          <div :if={is_nil(@chart_preview)} data-role="chart-placeholder" class="text-center py-8">
            <p class="text-base-content/60 text-sm">
              Select a metric and click Preview Chart to see a sample.
            </p>
          </div>

          <div
            :if={not is_nil(@chart_preview)}
            id="visualization-preview-chart"
            data-role="vega-lite-chart"
            phx-hook="VegaLite"
            data-spec={Jason.encode!(@chart_preview)}
            class="w-full"
          >
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
    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Handle params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope
    id_int = String.to_integer(id)

    case Dashboards.get_visualization(scope, id_int) do
      {:ok, visualization} ->
        socket =
          socket
          |> assign(:visualization, visualization)
          |> assign(:name, visualization.name || "")
          |> assign(:name_error, nil)
          |> assign(:selected_metric, extract_metric_name(visualization.vega_spec))
          |> assign(:selected_chart_type, extract_chart_type(visualization.vega_spec))
          |> assign(:shareable, visualization.shareable)
          |> assign(:chart_preview, visualization.vega_spec)
          |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
          |> assign(:chart_types, @chart_types)
          |> assign(:page_title, "Edit Visualization")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Visualization not found.")
         |> redirect(to: "/dashboards")}
    end
  end

  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:visualization, nil)
      |> assign(:name, "")
      |> assign(:name_error, nil)
      |> assign(:selected_metric, nil)
      |> assign(:selected_chart_type, "line")
      |> assign(:shareable, false)
      |> assign(:chart_preview, nil)
      |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
      |> assign(:chart_types, @chart_types)
      |> assign(:page_title, "New Visualization")

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate_name", %{"name" => name}, socket) do
    error =
      name
      |> Dashboards.visualization_name_changeset()
      |> name_error_from_changeset()

    {:noreply, assign(socket, name: name, name_error: error)}
  end

  def handle_event("select_metric", %{"metric" => metric}, socket) do
    {:noreply, assign(socket, selected_metric: metric, chart_preview: nil)}
  end

  def handle_event("select_chart_type", %{"chart_type" => type}, socket) do
    {:noreply, assign(socket, :selected_chart_type, type)}
  end

  def handle_event("preview_chart", _params, %{assigns: %{selected_metric: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("preview_chart", _params, socket) do
    scope = socket.assigns.current_scope
    metric = socket.assigns.selected_metric
    available = Dashboards.list_available_metrics(scope)

    case metric in available do
      false ->
        {:noreply, put_flash(socket, :error, "Selected metric is no longer available.")}

      true ->
        spec = Dashboards.build_chart_spec(metric, build_sample_data())
        {:noreply, assign(socket, :chart_preview, spec)}
    end
  end

  def handle_event("toggle_shareable", _params, socket) do
    {:noreply, assign(socket, :shareable, !socket.assigns.shareable)}
  end

  def handle_event("save_visualization", _params, socket) do
    name = socket.assigns.name
    metric = socket.assigns.selected_metric

    with :ok <- validate_name_present(name),
         :ok <- validate_metric_present(metric) do
      do_save(socket)
    else
      {:error, :name_blank} ->
        error =
          name
          |> Dashboards.visualization_name_changeset()
          |> name_error_from_changeset()

        {:noreply, assign(socket, :name_error, error)}

      {:error, :metric_missing} ->
        {:noreply, put_flash(socket, :error, "Please select a metric before saving.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_save(socket) do
    scope = socket.assigns.current_scope
    name = socket.assigns.name
    metric = socket.assigns.selected_metric
    chart_type = socket.assigns.selected_chart_type
    shareable = socket.assigns.shareable
    preview = socket.assigns.chart_preview

    vega_spec = preview || Dashboards.build_chart_spec(metric, build_sample_data())

    attrs = %{
      name: name,
      metric_name: metric,
      chart_type: chart_type,
      shareable: shareable,
      vega_spec: vega_spec
    }

    persist_visualization(socket, scope, socket.assigns.visualization, attrs)
  end

  defp persist_visualization(socket, scope, nil, attrs) do
    case Dashboards.save_visualization(scope, attrs) do
      {:ok, _visualization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Visualization saved.")
         |> push_navigate(to: "/dashboards")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_error, name_error_from_changeset(changeset))}
    end
  end

  defp persist_visualization(socket, scope, %Visualization{} = visualization, attrs) do
    case Dashboards.update_visualization(scope, visualization, attrs) do
      {:ok, _visualization} ->
        {:noreply,
         socket
         |> put_flash(:info, "Visualization saved.")
         |> push_navigate(to: "/dashboards")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_error, name_error_from_changeset(changeset))}
    end
  end

  defp validate_name_present(""), do: {:error, :name_blank}
  defp validate_name_present(nil), do: {:error, :name_blank}
  defp validate_name_present(_name), do: :ok

  defp validate_metric_present(nil), do: {:error, :metric_missing}
  defp validate_metric_present(_metric), do: :ok

  defp page_title_for(:new), do: "New Visualization"
  defp page_title_for(:edit), do: "Edit Visualization"
  defp page_title_for(_), do: "Visualization"

  defp name_error_from_changeset(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :name) do
      nil ->
        nil

      {msg, opts} ->
        if count = opts[:count] do
          Gettext.dngettext(MetricFlowWeb.Gettext, "errors", msg, msg, count, opts)
        else
          Gettext.dgettext(MetricFlowWeb.Gettext, "errors", msg, opts)
        end
    end
  end

  defp extract_metric_name(%{"title" => title}) when is_binary(title), do: title
  defp extract_metric_name(_), do: nil

  defp extract_chart_type(%{"mark" => mark}) when is_binary(mark) and mark in @chart_types,
    do: mark

  defp extract_chart_type(_), do: "line"

  defp build_sample_data do
    today = Date.utc_today()

    Enum.map(0..6, fn days_ago ->
      %{date: Date.add(today, -days_ago), value: :rand.uniform() * 100}
    end)
  end
end
