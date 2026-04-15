defmodule MetricFlowWeb.DashboardLive.Editor do
  @moduledoc """
  LiveView for creating and editing custom dashboards.

  Allows authenticated users to build reports by composing visualizations from
  connected platform metrics, placing them into a named layout, and saving the
  result. Supports creating a new dashboard from a blank canvas or a canned
  template, and editing an existing saved dashboard.

  Requires authentication; unauthenticated requests are redirected to
  `/users/log-in` by the router's `:require_authenticated_user` pipeline. All
  `Dashboards` context calls receive `socket.assigns.current_scope` so queries
  are scoped to the active account.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards
  alias MetricFlow.Dashboards.Dashboard

  @chart_types ["line", "bar", "area"]

  @templates %{
    "marketing_overview" => %{
      label: "Marketing Overview",
      description: "Clicks, Spend, Impressions, and ROAS at a glance",
      visualizations: [
        %{metric_name: "Clicks", chart_type: "bar", position: 0},
        %{metric_name: "Spend", chart_type: "line", position: 1},
        %{metric_name: "Impressions", chart_type: "area", position: 2},
        %{metric_name: "ROAS", chart_type: "line", position: 3}
      ]
    },
    "financial_summary" => %{
      label: "Financial Summary",
      description: "Revenue, Conversions, and CPC trends",
      visualizations: [
        %{metric_name: "Revenue", chart_type: "line", position: 0},
        %{metric_name: "Conversions", chart_type: "bar", position: 1},
        %{metric_name: "CPC", chart_type: "line", position: 2}
      ]
    }
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
      active_account_type={assigns[:active_account_type]}
    >
    <div>
      <%!-- Header row --%>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-bold">
          {page_title_for(@live_action)}
        </h1>
        <div class="flex items-center gap-2">
          <button
            phx-click="save_dashboard"
            data-role="save-dashboard-btn"
            class="btn btn-primary"
          >
            Save Dashboard
          </button>
          <.link navigate="/app/dashboards" class="btn btn-ghost">Cancel</.link>
        </div>
      </div>

      <%!-- Dashboard name field --%>
      <form phx-change="validate_name" phx-submit="save_dashboard" class="form-control mb-6">
        <label class="label">
          <span class="label-text">Dashboard Name</span>
        </label>
        <input
          type="text"
          name="dashboard[name]"
          value={@changeset.params["name"] || (@dashboard && @dashboard.name) || ""}
          data-role="dashboard-name-input"
          class={["input w-full", has_name_error?(@changeset) && "input-error"]}
          placeholder="My Dashboard"
        />
        <p :if={has_name_error?(@changeset)} class="text-sm text-error mt-1">
          {name_error(@changeset)}
        </p>
      </form>

      <%!-- Visualization count error --%>
      <p :if={@viz_error} class="text-sm text-error mb-4">
        {@viz_error}
      </p>

      <%!-- Template chooser (create route, empty canvas) --%>
      <div
        :if={@live_action == :new and @visualizations == []}
        data-role="template-chooser"
        class="mb-6"
      >
        <p class="text-base-content/60 mb-3">Start from a template or blank canvas</p>
        <div class="grid grid-cols-2 sm:grid-cols-4 gap-4">
          <div
            :for={{key, tpl} <- @templates}
            phx-click="select_template"
            phx-value-template={key}
            data-role={"template-card-#{key}"}
            class={[
              "mf-card p-4 cursor-pointer",
              @selected_template == key && "ring-2 ring-primary"
            ]}
          >
            <p class="font-semibold text-sm">{tpl.label}</p>
            <p class="text-xs text-base-content/60 mt-1">{tpl.description}</p>
          </div>

          <div
            phx-click="clear_canvas"
            phx-confirm="Clear the canvas? All visualizations will be removed."
            data-role="template-card-blank"
            class={[
              "mf-card p-4 cursor-pointer",
              @selected_template == "blank" && "ring-2 ring-primary"
            ]}
          >
            <p class="font-semibold text-sm">Blank Canvas</p>
            <p class="text-xs text-base-content/60 mt-1">Start with an empty dashboard</p>
          </div>
        </div>
      </div>

      <%!-- Add Visualization button --%>
      <button
        phx-click="open_metric_picker"
        data-role="add-visualization-btn"
        class="btn btn-outline btn-sm mb-4"
      >
        + Add Visualization
      </button>

      <%!-- Metric picker panel --%>
      <div
        :if={@picker_open}
        data-role="metric-picker"
        class="mf-card p-5 mb-6"
      >
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-base font-semibold">Add Visualization</h3>
          <button
            phx-click="close_metric_picker"
            data-role="close-metric-picker"
            aria-label="Close metric picker"
            class="btn btn-ghost btn-xs"
          >
            ✕
          </button>
        </div>

        <%!-- Metric list --%>
        <div data-role="metric-list" class="flex flex-wrap gap-2 mb-4 max-h-40 overflow-y-auto">
          <button
            :for={metric <- @available_metrics}
            phx-click="select_metric"
            phx-value-metric={metric}
            class={[
              "btn btn-sm",
              @picker_selected_metric == metric && "btn-primary",
              @picker_selected_metric != metric && "btn-ghost"
            ]}
          >
            {metric}
          </button>
          <p :if={@available_metrics == []} class="text-sm text-base-content/60">
            No metrics available. Connect a platform to get started.
          </p>
        </div>

        <%!-- Chart type selector --%>
        <div data-role="chart-type-selector" class="flex items-center gap-2 mb-4">
          <button
            :for={type <- @chart_types}
            phx-click="select_chart_type"
            phx-value-chart_type={type}
            class={[
              "btn btn-sm",
              @picker_selected_chart_type == type && "btn-primary",
              @picker_selected_chart_type != type && "btn-ghost"
            ]}
          >
            {String.capitalize(type)}
          </button>
        </div>

        <%!-- Confirm add button --%>
        <button
          phx-click="add_visualization"
          data-role="confirm-add-btn"
          disabled={is_nil(@picker_selected_metric)}
          class="btn btn-primary btn-sm"
        >
          Add to Dashboard
        </button>
      </div>

      <%!-- Visualization canvas --%>
      <div data-role="visualization-canvas" class="space-y-4 mb-6">
        <div :if={@visualizations == []} data-role="empty-canvas" class="mf-card p-8 text-center">
          <p class="text-base-content/60">Add a visualization to get started</p>
        </div>

        <div
          :for={{viz, idx} <- Enum.with_index(@visualizations)}
          data-role="visualization-card"
          class="mf-card p-4"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <span class="font-semibold">{viz.metric_name}</span>
              <span class="badge badge-ghost badge-sm">{viz.chart_type}</span>
            </div>
            <div class="flex items-center gap-1">
              <button
                phx-click="move_visualization_up"
                phx-value-index={idx}
                aria-label="Move up"
                class="btn btn-ghost btn-xs"
              >
                ↑
              </button>
              <button
                phx-click="move_visualization_down"
                phx-value-index={idx}
                aria-label="Move down"
                class="btn btn-ghost btn-xs"
              >
                ↓
              </button>
              <button
                phx-click="remove_visualization"
                phx-value-index={idx}
                aria-label="Remove"
                class="btn btn-ghost btn-xs btn-error"
              >
                ✕
              </button>
            </div>
          </div>

          <div
            data-role="chart-preview"
            class="mt-2 h-32 flex items-center justify-center bg-base-200 rounded"
          >
            <p class="text-sm text-base-content/50">No data yet</p>
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
    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Handle Params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope
    id_int = String.to_integer(id)

    case Dashboards.get_dashboard_with_visualizations(scope, id_int) do
      {:ok, dashboard} ->
        changeset = Dashboards.dashboard_changeset(dashboard, %{})
        visualizations = load_visualizations_from_dashboard(dashboard)

        socket =
          socket
          |> assign(:dashboard, dashboard)
          |> assign(:changeset, changeset)
          |> assign(:visualizations, visualizations)
          |> assign(:picker_open, false)
          |> assign(:picker_selected_metric, nil)
          |> assign(:picker_selected_chart_type, "line")
          |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
          |> assign(:templates, @templates)
          |> assign(:selected_template, nil)
          |> assign(:chart_types, @chart_types)
          |> assign(:viz_error, nil)
          |> assign(:page_title, "Edit Dashboard")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Dashboard not found.")
         |> redirect(to: "/app/dashboards")}
    end
  end

  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope
    changeset = Dashboards.dashboard_changeset(%Dashboard{}, %{})

    socket =
      socket
      |> assign(:dashboard, nil)
      |> assign(:changeset, changeset)
      |> assign(:visualizations, [])
      |> assign(:picker_open, false)
      |> assign(:picker_selected_metric, nil)
      |> assign(:picker_selected_chart_type, "line")
      |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
      |> assign(:templates, @templates)
      |> assign(:selected_template, nil)
      |> assign(:chart_types, @chart_types)
      |> assign(:viz_error, nil)
      |> assign(:page_title, "New Dashboard")

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("validate_name", %{"dashboard" => %{"name" => name}}, socket) do
    dashboard = socket.assigns.dashboard || %Dashboard{}

    changeset =
      Dashboards.dashboard_changeset(dashboard, %{"name" => name, "user_id" => 0})
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  def handle_event("save_dashboard", _params, socket) do
    case socket.assigns.visualizations do
      [] ->
        {:noreply,
         assign(socket, :viz_error, "Please add at least one visualization to save the dashboard.")}

      _visualizations ->
        do_save(socket)
    end
  end

  def handle_event("open_metric_picker", _params, socket) do
    socket =
      socket
      |> assign(:picker_open, true)
      |> assign(:picker_selected_metric, nil)
      |> assign(:picker_selected_chart_type, "line")

    {:noreply, socket}
  end

  def handle_event("close_metric_picker", _params, socket) do
    {:noreply, assign(socket, :picker_open, false)}
  end

  def handle_event("select_metric", %{"metric" => metric}, socket) do
    {:noreply, assign(socket, :picker_selected_metric, metric)}
  end

  def handle_event("select_chart_type", %{"chart_type" => type}, socket) do
    {:noreply, assign(socket, :picker_selected_chart_type, type)}
  end

  def handle_event("add_visualization", _params, %{assigns: %{picker_selected_metric: nil}} = socket) do
    {:noreply, socket}
  end

  def handle_event("add_visualization", _params, socket) do
    metric = socket.assigns.picker_selected_metric
    chart_type = socket.assigns.picker_selected_chart_type
    next_position = length(socket.assigns.visualizations)

    new_viz = %{metric_name: metric, chart_type: chart_type, position: next_position}
    visualizations = socket.assigns.visualizations ++ [new_viz]

    socket =
      socket
      |> assign(:visualizations, visualizations)
      |> assign(:picker_open, false)
      |> assign(:picker_selected_metric, nil)
      |> assign(:picker_selected_chart_type, "line")
      |> assign(:viz_error, nil)

    {:noreply, socket}
  end

  def handle_event("remove_visualization", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)

    visualizations =
      socket.assigns.visualizations
      |> List.delete_at(index)
      |> renumber_positions()

    {:noreply, assign(socket, :visualizations, visualizations)}
  end

  def handle_event("move_visualization_up", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    visualizations = swap_at(socket.assigns.visualizations, index, index - 1)
    {:noreply, assign(socket, :visualizations, visualizations)}
  end

  def handle_event("move_visualization_down", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    visualizations = swap_at(socket.assigns.visualizations, index, index + 1)
    {:noreply, assign(socket, :visualizations, visualizations)}
  end

  def handle_event("select_template", %{"template" => template_key}, socket) do
    case Map.get(@templates, template_key) do
      nil ->
        {:noreply, socket}

      template ->
        socket =
          socket
          |> assign(:visualizations, template.visualizations)
          |> assign(:selected_template, template_key)
          |> assign(:viz_error, nil)

        {:noreply, socket}
    end
  end

  def handle_event("clear_canvas", _params, socket) do
    socket =
      socket
      |> assign(:visualizations, [])
      |> assign(:selected_template, "blank")

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp do_save(socket) do
    scope = socket.assigns.current_scope
    name = extract_name(socket.assigns.changeset)
    attrs = %{"name" => name}
    visualizations = socket.assigns.visualizations

    case socket.assigns.dashboard do
      nil ->
        with {:ok, dashboard} <- Dashboards.save_dashboard(scope, attrs),
             :ok <- Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations) do
          {:noreply,
           socket
           |> put_flash(:info, "Dashboard created.")
           |> push_navigate(to: ~p"/app/dashboards/#{dashboard.id}")}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to save dashboard. Please try again.")}
        end

      dashboard ->
        with {:ok, updated} <- Dashboards.update_dashboard(scope, dashboard, attrs),
             :ok <- Dashboards.replace_dashboard_visualizations(scope, updated, visualizations) do
          {:noreply,
           socket
           |> put_flash(:info, "Dashboard updated.")
           |> push_navigate(to: ~p"/app/dashboards/#{updated.id}")}
        else
          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to save dashboard. Please try again.")}
        end
    end
  end

  defp load_visualizations_from_dashboard(%Dashboard{dashboard_visualizations: dvs})
       when is_list(dvs) do
    dvs
    |> Enum.sort_by(& &1.position)
    |> Enum.map(fn dv ->
      vega_spec = dv.visualization.vega_spec || %{}
      metric_name = Map.get(vega_spec, "metric_name") || dv.visualization.name
      chart_type = Map.get(vega_spec, "chart_type") || "line"
      %{metric_name: metric_name, chart_type: chart_type, position: dv.position}
    end)
  end

  defp load_visualizations_from_dashboard(%Dashboard{}), do: []

  defp page_title_for(:new), do: "New Dashboard"
  defp page_title_for(:edit), do: "Edit Dashboard"
  defp page_title_for(_), do: "Dashboard"

  defp has_name_error?(%Ecto.Changeset{action: nil}), do: false

  defp has_name_error?(%Ecto.Changeset{} = changeset) do
    changeset.errors
    |> Keyword.get(:name)
    |> is_nil()
    |> Kernel.not()
  end

  defp name_error(%Ecto.Changeset{} = changeset) do
    case Keyword.get(changeset.errors, :name) do
      nil -> nil
      {msg, _opts} -> msg
    end
  end

  defp extract_name(%Ecto.Changeset{} = changeset) do
    case Ecto.Changeset.get_field(changeset, :name) do
      nil -> changeset.params["name"] || ""
      name -> name
    end
  end

  defp renumber_positions(visualizations) do
    visualizations
    |> Enum.with_index()
    |> Enum.map(fn {viz, idx} -> %{viz | position: idx} end)
  end

  defp swap_at(list, i, j)
       when i >= 0 and j >= 0 and i < length(list) and j < length(list) do
    elem_i = Enum.at(list, i)
    elem_j = Enum.at(list, j)

    list
    |> List.replace_at(i, elem_j)
    |> List.replace_at(j, elem_i)
    |> renumber_positions()
  end

  defp swap_at(list, _i, _j), do: list
end
