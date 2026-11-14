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

  alias MetricFlow.Ai
  alias MetricFlow.Ai.DashboardBuilder
  alias MetricFlow.Dashboards
  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Metrics

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

      <%!-- Build with AI chat --%>
      <div data-role="dashboard-chat-panel" class="mf-card p-4 mb-6">
        <h2 class="text-base font-semibold mb-1">Build with AI</h2>
        <p class="text-sm text-base-content/60 mb-3">
          Describe the dashboard you want and the agent will add it to the canvas below.
        </p>

        <div
          :if={@dashboard_chat_messages != []}
          data-role="dashboard-chat-messages"
          class="space-y-2 mb-3 max-h-48 overflow-y-auto"
        >
          <div
            :for={msg <- @dashboard_chat_messages}
            data-role="dashboard-chat-message"
            class={[
              "p-2 rounded text-sm",
              msg.role == :user && "bg-primary/10",
              msg.role == :assistant && "bg-base-200"
            ]}
          >
            <p class="font-semibold text-xs mb-1 text-base-content/60">
              {if msg.role == :user, do: "You", else: "Agent"}
            </p>
            <p class="whitespace-pre-wrap">{msg.content}</p>
            <.link
              :if={Map.get(msg, :link)}
              navigate={msg.link.href}
              class="text-primary underline text-xs"
            >
              {msg.link.text}
            </.link>
          </div>
        </div>

        <form phx-submit="send_dashboard_chat" data-role="dashboard-chat-form">
          <div class="flex gap-2">
            <textarea
              name="message"
              data-role="dashboard-chat-input"
              rows="2"
              placeholder="e.g. a headline stat, a spend-over-time line chart and a table of campaigns"
              disabled={@dashboard_chat_generating}
              class="textarea textarea-bordered textarea-sm flex-1 resize-none"
            ></textarea>
            <button
              type="submit"
              data-role="dashboard-chat-send-btn"
              disabled={@dashboard_chat_generating}
              class={["btn btn-primary btn-sm self-end", @dashboard_chat_generating && "btn-disabled"]}
            >
              <span :if={@dashboard_chat_generating} class="loading loading-spinner loading-xs" />
              <span :if={!@dashboard_chat_generating}>Send</span>
            </button>
          </div>
          <p :if={@dashboard_chat_error} class="text-error text-xs mt-1" data-role="dashboard-chat-error">
            {@dashboard_chat_error}
          </p>
        </form>
      </div>

      <%!-- Versions (Story 74, rule 7: every agent change is a restorable version) --%>
      <div :if={@dashboard_versions != []} data-role="dashboard-version-list" class="mf-card p-4 mb-6">
        <h2 class="text-base font-semibold mb-2">Versions</h2>
        <ul class="space-y-1">
          <li
            :for={{version, idx} <- Enum.with_index(@dashboard_versions)}
            data-role="dashboard-version"
            class="flex items-center justify-between gap-2 text-sm text-base-content/70"
          >
            <span>
              Version {length(@dashboard_versions) - idx} -- {Calendar.strftime(
                version.inserted_at,
                "%b %d, %Y %H:%M"
              )}
            </span>
            <button
              phx-click="restore_version"
              phx-value-id={version.id}
              data-role="restore-version"
              class="btn btn-ghost btn-xs"
            >
              Restore
            </button>
          </li>
        </ul>
      </div>

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

        <%!-- Insert from the visualization library --%>
        <div :if={@library_visualizations != []} class="mt-4 pt-4 border-t border-base-300">
          <p class="text-sm font-medium mb-2">Or insert from your visualization library:</p>
          <div data-role="library-visualization-list" class="flex flex-wrap gap-2">
            <button
              :for={viz <- @library_visualizations}
              phx-click="insert_library_visualization"
              phx-value-id={viz.id}
              data-role="library-visualization-option"
              class="btn btn-sm btn-ghost"
            >
              {viz.name}
            </button>
          </div>
        </div>
      </div>

      <%!-- Story 74, rule 5: an interactive control that only re-runs
           metric queries and changes what is shown -- it never writes
           anywhere or calls any tool. --%>
      <div data-role="filter-control" class="mf-card p-3 mb-6 flex items-center gap-2">
        <label class="text-sm text-base-content/70" for="dashboard-date-range">Date range</label>
        <form phx-change="filter_date_range">
          <select
            id="dashboard-date-range"
            name="range"
            class="select select-sm select-bordered"
          >
            <option value="7" selected={@dashboard_date_range == "7"}>Last 7 days</option>
            <option value="30" selected={@dashboard_date_range == "30"}>Last 30 days</option>
            <option value="90" selected={@dashboard_date_range == "90"}>Last 90 days</option>
          </select>
        </form>
      </div>

      <%!-- Visualization canvas --%>
      <div
        id="visualization-canvas"
        data-role="visualization-canvas"
        phx-hook="SortableList"
        class="space-y-4 mb-6"
      >
        <div :if={@visualizations == []} data-role="empty-canvas" class="mf-card p-8 text-center">
          <p class="text-base-content/60">Add a visualization to get started</p>
        </div>

        <div
          :for={{viz, idx} <- Enum.with_index(@visualizations)}
          data-role="visualization-card"
          draggable="true"
          class="mf-card p-4"
        >
          <div class="flex items-center justify-between mb-2">
            <div class="flex items-center gap-2">
              <span data-role="drag-handle" class="cursor-grab text-base-content/40" aria-label="Drag to reorder">
                ⠿
              </span>
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

          <%!-- Story 74: "Charts are ECharts"; "Chat only: no hand-edit spec editor." --%>
          <div
            data-role="chart-preview"
            class="mt-2 h-32 bg-base-200 rounded overflow-hidden flex items-center justify-center"
          >
            <p
              :if={elem(Enum.at(@chart_render, idx), 0) == :stat}
              data-role="stat-tile-value"
              class="text-3xl font-bold"
            >
              {elem(Enum.at(@chart_render, idx), 1)}
            </p>
            <div
              :if={elem(Enum.at(@chart_render, idx), 0) == :chart}
              id={"dashboard-chart-#{idx}"}
              data-role="echarts-chart"
              phx-hook="ECharts"
              phx-update="ignore"
              data-option={Jason.encode!(elem(Enum.at(@chart_render, idx), 1))}
              class="w-full h-full"
            >
            </div>
            <p
              :if={elem(Enum.at(@chart_render, idx), 0) == :no_data}
              data-role="no-data-message"
              class="text-sm text-base-content/60"
            >
              No data for this period
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
        {chat_messages, chat_session_id} = load_dashboard_chat_history(scope, dashboard.id)

        socket =
          socket
          |> assign(:dashboard, dashboard)
          |> assign(:changeset, changeset)
          |> assign(:visualizations, visualizations)
          |> assign(:chart_specs, resolve_chart_specs(visualizations, scope))
          |> assign(
            :chart_render,
            resolve_chart_render(visualizations, scope, date_range_for(dashboard.date_range || "30"))
          )
          |> assign(:picker_open, false)
          |> assign(:picker_selected_metric, nil)
          |> assign(:picker_selected_chart_type, "line")
          |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
          |> assign(:templates, @templates)
          |> assign(:selected_template, nil)
          |> assign(:chart_types, @chart_types)
          |> assign(:viz_error, nil)
          |> assign(:library_visualizations, Dashboards.list_visualizations(scope))
          |> assign(:dashboard_chat_messages, chat_messages)
          |> assign(:dashboard_chat_generating, false)
          |> assign(:dashboard_chat_error, nil)
          |> assign(:dashboard_chat_context, nil)
          |> assign(:dashboard_chat_session_id, chat_session_id)
          |> assign(:dashboard_chat_pending_message, nil)
          |> assign(:dashboard_versions, Dashboards.list_dashboard_versions(dashboard))
          |> assign(:dashboard_date_range, dashboard.date_range || "30")
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
      |> assign(:chart_specs, [])
      |> assign(:chart_render, [])
      |> assign(:picker_open, false)
      |> assign(:picker_selected_metric, nil)
      |> assign(:picker_selected_chart_type, "line")
      |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
      |> assign(:templates, @templates)
      |> assign(:selected_template, nil)
      |> assign(:chart_types, @chart_types)
      |> assign(:viz_error, nil)
      |> assign(:library_visualizations, Dashboards.list_visualizations(scope))
      |> assign(:dashboard_chat_messages, [])
      |> assign(:dashboard_chat_generating, false)
      |> assign(:dashboard_chat_error, nil)
      |> assign(:dashboard_chat_context, nil)
      |> assign(:dashboard_chat_session_id, nil)
      |> assign(:dashboard_chat_pending_message, nil)
      |> assign(:dashboard_versions, [])
      |> assign(:dashboard_date_range, "30")
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
    scope = socket.assigns.current_scope

    socket =
      socket
      |> assign(:visualizations, visualizations)
      |> assign(
        :chart_render,
        resolve_chart_render(visualizations, scope, date_range_for(socket.assigns.dashboard_date_range))
      )
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

    {:noreply, assign_visualizations(socket, visualizations)}
  end

  def handle_event("move_visualization_up", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    visualizations = swap_at(socket.assigns.visualizations, index, index - 1)
    {:noreply, assign_visualizations(socket, visualizations)}
  end

  def handle_event("move_visualization_down", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    visualizations = swap_at(socket.assigns.visualizations, index, index + 1)
    {:noreply, assign_visualizations(socket, visualizations)}
  end

  def handle_event("reorder_visualizations", %{"from" => from_str, "to" => to_str}, socket) do
    from_index = String.to_integer(to_string(from_str))
    to_index = String.to_integer(to_string(to_str))
    visualizations = move_at(socket.assigns.visualizations, from_index, to_index)
    {:noreply, assign_visualizations(socket, visualizations)}
  end

  def handle_event("select_template", %{"template" => template_key}, socket) do
    case Map.get(@templates, template_key) do
      nil ->
        {:noreply, socket}

      template ->
        socket =
          socket
          |> assign_visualizations(template.visualizations)
          |> assign(:selected_template, template_key)
          |> assign(:viz_error, nil)

        {:noreply, socket}
    end
  end

  def handle_event("clear_canvas", _params, socket) do
    socket =
      socket
      |> assign_visualizations([])
      |> assign(:selected_template, "blank")

    {:noreply, socket}
  end

  def handle_event("insert_library_visualization", %{"id" => id_str}, socket) do
    scope = socket.assigns.current_scope

    case Dashboards.get_visualization(scope, String.to_integer(id_str)) do
      {:ok, viz} ->
        next_position = length(socket.assigns.visualizations)
        raw_spec = viz.vega_spec || %{}
        frozen_spec = custom_spec(raw_spec)

        new_viz = %{
          metric_name: Map.get(raw_spec, "metric_name") || viz.name,
          chart_type: Map.get(raw_spec, "chart_type") || extract_chart_type_from_spec(raw_spec),
          position: next_position,
          vega_spec: frozen_spec
        }

        visualizations = socket.assigns.visualizations ++ [new_viz]

        socket =
          socket
          |> assign(:visualizations, visualizations)
          |> assign(:chart_specs, resolve_chart_specs(visualizations, scope))
          |> assign(
            :chart_render,
            resolve_chart_render(visualizations, scope, date_range_for(socket.assigns.dashboard_date_range))
          )
          |> assign(:picker_open, false)
          |> assign(:viz_error, nil)

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Visualization not found.")}
    end
  end

  def handle_event("send_dashboard_chat", %{"message" => message}, socket) do
    case String.trim(message) do
      "" ->
        {:noreply, socket}

      trimmed ->
        send_dashboard_chat_message(socket, trimmed)
    end
  end

  # Story 74, rule 7: restoring an earlier version shows what the dashboard
  # looked like then, and the restore itself appears as a new version.
  def handle_event("restore_version", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)

    case Enum.find(socket.assigns.dashboard_versions, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      version ->
        scope = socket.assigns.current_scope
        dashboard = socket.assigns.dashboard
        visualizations = visualizations_from_version(version)

        with :ok <- Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations),
             {:ok, dashboard} <-
               Dashboards.update_dashboard(scope, dashboard, %{
                 "a2ui_spec" => build_a2ui_spec(visualizations)
               }) do
          socket =
            socket
            |> assign(:dashboard, dashboard)
            |> assign_visualizations(visualizations)
            |> record_dashboard_version(dashboard, visualizations)

          {:noreply, socket}
        else
          _ -> {:noreply, socket}
        end
    end
  end

  # Story 74, rule 5: changing the range only re-runs what is shown, not a
  # model/tool call. Rule 8: the chosen value is saved with the dashboard
  # itself so it survives a reopen -- there's nothing to save yet for a
  # dashboard the agent hasn't built anything on.
  def handle_event("filter_date_range", %{"range" => range}, socket) do
    socket =
      socket
      |> assign(:dashboard_date_range, range)
      |> assign_visualizations(socket.assigns.visualizations)

    case socket.assigns.dashboard do
      %Dashboard{} = dashboard ->
        scope = socket.assigns.current_scope

        case Dashboards.update_dashboard(scope, dashboard, %{"date_range" => range}) do
          {:ok, dashboard} -> {:noreply, assign(socket, :dashboard, dashboard)}
          {:error, _} -> {:noreply, socket}
        end

      nil ->
        {:noreply, socket}
    end
  end

  # ---------------------------------------------------------------------------
  # Async dashboard chat result handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({ref, {:ok, %{text: text, spec: a2ui_spec, context: updated_context}}}, socket)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    user_text = socket.assigns.dashboard_chat_pending_message
    assistant_msg = %{role: :assistant, content: text}

    socket =
      socket
      |> append_chat_message(assistant_msg)
      |> assign(:dashboard_chat_context, updated_context)
      |> assign(:dashboard_chat_generating, false)
      |> apply_a2ui_spec(a2ui_spec)
      |> persist_dashboard_chat_turn(user_text, text)

    {:noreply, socket}
  end

  def handle_info({ref, {:error, {:unresolvable_metric, names}}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    error_msg =
      "I don't have data for #{Enum.join(names, ", ")} yet. Connect that platform in Integrations."

    {:noreply, finish_dashboard_chat_with_error(socket, error_msg)}
  end

  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    require Logger
    Logger.error("dashboard chat error: #{inspect(reason)}")

    {:noreply, finish_dashboard_chat_with_error(socket, "The agent couldn't build that. Please try again.")}
  end

  # Reaching here means the task crashed before sending {ref, result} -- a normal
  # completion is already consumed and demonitor-flushed above.
  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    require Logger
    Logger.error("dashboard chat task crashed: #{inspect(reason)}")

    {:noreply, finish_dashboard_chat_with_error(socket, "The AI service is unavailable right now.")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp send_dashboard_chat_message(socket, trimmed) do
    case socket.assigns.available_metrics do
      [] ->
        error_msg = "No metrics are available yet."

        assistant_msg = %{
          role: :assistant,
          content: error_msg,
          link: %{href: "/app/integrations", text: "Connect a platform"}
        }

        socket =
          socket
          |> append_chat_message(%{role: :user, content: trimmed})
          |> append_chat_message(assistant_msg)

        {:noreply, socket}

      metric_names ->
        context = socket.assigns.dashboard_chat_context
        current_spec = socket.assigns.dashboard && socket.assigns.dashboard.a2ui_spec
        runner = Application.get_env(:metric_flow, :command_runner)

        Task.async(fn ->
          DashboardBuilder.send_message(
            context,
            trimmed,
            metric_names: metric_names,
            command_runner: runner,
            current_spec: current_spec
          )
        end)

        socket =
          socket
          |> append_chat_message(%{role: :user, content: trimmed})
          |> assign(:dashboard_chat_generating, true)
          |> assign(:dashboard_chat_error, nil)
          |> assign(:dashboard_chat_pending_message, trimmed)

        {:noreply, socket}
    end
  end

  defp append_chat_message(socket, message) do
    assign(socket, :dashboard_chat_messages, socket.assigns.dashboard_chat_messages ++ [message])
  end

  defp finish_dashboard_chat_with_error(socket, error_msg) do
    socket
    |> append_chat_message(%{role: :assistant, content: "Error: #{error_msg}"})
    |> assign(:dashboard_chat_generating, false)
    |> assign(:dashboard_chat_error, error_msg)
  end

  # Story 74: set_dashboard_spec always returns the dashboard's complete
  # A2UI spec, so there's nothing to merge widget-by-widget -- it replaces
  # the whole canvas outright. A turn that never calls the tool (a
  # question, a halted/unresolvable-metric turn) leaves the canvas as-is.
  defp apply_a2ui_spec(socket, nil), do: socket

  defp apply_a2ui_spec(socket, a2ui_spec) do
    visualizations = visualizations_from_a2ui_spec(a2ui_spec)

    socket
    |> assign_visualizations(visualizations)
    |> autosave_draft_dashboard(visualizations)
  end

  defp visualizations_from_a2ui_spec(%{"components" => components}) do
    components
    |> Enum.with_index()
    |> Enum.map(fn {component, position} ->
      %{
        metric_name: a2ui_component_title(component),
        chart_type: a2ui_component_chart_type(component),
        position: position,
        vega_spec: component
      }
    end)
  end

  defp visualizations_from_a2ui_spec(_a2ui_spec), do: []

  defp a2ui_component_title(%{"title" => title}) when is_binary(title), do: title
  defp a2ui_component_title(component), do: get_in(component, ["query", "metric"]) || "Untitled"

  defp a2ui_component_chart_type(component), do: a2ui_component_chart_type_or_nil(component) || "line"

  # Returns nil (rather than defaulting) for anything that doesn't look like
  # an A2UI component at all, so a caller juggling both shapes -- a
  # reloaded Visualization row can hold either, depending on whether it was
  # built via chat (A2UI) or the old template/library/manual paths
  # (Vega-Lite) -- can fall through to its own Vega-Lite-specific handling.
  defp a2ui_component_chart_type_or_nil(%{"type" => "stat"}), do: "text"

  defp a2ui_component_chart_type_or_nil(%{"type" => "chart", "chartType" => type})
       when is_binary(type),
       do: type

  defp a2ui_component_chart_type_or_nil(%{"type" => "chart"}), do: "line"
  defp a2ui_component_chart_type_or_nil(_component), do: nil

  # Story 74, rule 1: the first thing the agent builds is saved as a draft
  # with no explicit Save -- once a dashboard already exists we just keep
  # replacing its visualizations on every later build.
  # Story 74, rule 1: the first build saves a draft with no explicit Save.
  # Story 74, rule 7: every later change -- including this first one -- is
  # recorded as a version.
  defp autosave_draft_dashboard(%{assigns: %{dashboard: %Dashboard{} = dashboard}} = socket, visualizations) do
    scope = socket.assigns.current_scope

    with :ok <- Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations),
         {:ok, dashboard} <-
           Dashboards.update_dashboard(scope, dashboard, %{"a2ui_spec" => build_a2ui_spec(visualizations)}) do
      socket
      |> assign(:dashboard, dashboard)
      |> record_dashboard_version(dashboard, visualizations)
    else
      _ -> socket
    end
  end

  defp autosave_draft_dashboard(socket, visualizations) do
    scope = socket.assigns.current_scope
    name = draft_dashboard_name(socket.assigns.changeset)
    a2ui_spec = build_a2ui_spec(visualizations)

    with {:ok, dashboard} <- Dashboards.save_dashboard(scope, %{"name" => name, "a2ui_spec" => a2ui_spec}),
         :ok <- Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations) do
      socket
      |> assign(:dashboard, dashboard)
      |> record_dashboard_version(dashboard, visualizations)
      |> push_patch(to: ~p"/app/dashboards/#{dashboard.id}/edit")
    else
      _ -> socket
    end
  end

  # Story 74's notes: the builder agent's one write tool sets an A2UI blob
  # ("components") on the dashboard; each chart/stat component binds to a
  # metric via a "query", never inline data/values -- data is fetched at
  # render time (see resolve_chart_render/2), so this never carries any.
  defp build_a2ui_spec(visualizations) do
    %{
      "components" => Enum.map(visualizations, &build_a2ui_component/1)
    }
  end

  defp build_a2ui_component(viz) do
    base = %{
      "id" => "widget-#{viz.position}",
      "type" => a2ui_component_type(viz.chart_type),
      "title" => viz.metric_name,
      "query" => %{"metric" => chart_metric_key(viz)}
    }

    case viz.chart_type do
      "text" -> base
      chart_type -> Map.put(base, "chartType", chart_type)
    end
  end

  defp a2ui_component_type("text"), do: "stat"
  defp a2ui_component_type(_chart_type), do: "chart"

  defp record_dashboard_version(socket, dashboard, visualizations) do
    case Dashboards.create_dashboard_version(dashboard, visualizations) do
      {:ok, version} ->
        assign(socket, :dashboard_versions, [version | socket.assigns.dashboard_versions])

      {:error, _} ->
        socket
    end
  end

  # A version's visualizations round-trip through jsonb as string-keyed maps;
  # the rest of this module works in the atom-keyed shape `add_visualization_*`
  # and `load_visualizations_from_dashboard/1` already use.
  defp visualizations_from_version(%{visualizations: visualizations}) do
    Enum.map(visualizations, fn viz ->
      %{
        metric_name: viz["metric_name"],
        chart_type: viz["chart_type"],
        position: viz["position"],
        vega_spec: viz["vega_spec"]
      }
    end)
  end

  defp draft_dashboard_name(changeset) do
    case extract_name(changeset) do
      "" -> "Untitled Dashboard"
      name -> name
    end
  end

  # Story 74, rule 1 again: nothing is persisted for a turn that never builds
  # a dashboard (a failed or declined request leaves no draft to attach
  # history to). Once a dashboard exists, its chat session is created once
  # -- with the dashboard's id already known, so there is no later backfill
  # -- and reused for every later turn.
  defp persist_dashboard_chat_turn(%{assigns: %{dashboard: nil}} = socket, _user_text, _assistant_text),
    do: socket

  defp persist_dashboard_chat_turn(socket, user_text, assistant_text) do
    scope = socket.assigns.current_scope
    {session_id, socket} = ensure_dashboard_chat_session(socket, scope, socket.assigns.dashboard)

    persist_dashboard_chat_message(scope, session_id, :user, user_text)
    persist_dashboard_chat_message(scope, session_id, :assistant, assistant_text)

    socket
  end

  defp ensure_dashboard_chat_session(%{assigns: %{dashboard_chat_session_id: id}} = socket, _scope, _dashboard)
       when not is_nil(id) do
    {id, socket}
  end

  defp ensure_dashboard_chat_session(socket, scope, dashboard) do
    case Ai.create_chat_session(scope, %{context_type: :dashboard, context_id: dashboard.id}) do
      {:ok, session} -> {session.id, assign(socket, :dashboard_chat_session_id, session.id)}
      {:error, _changeset} -> {nil, socket}
    end
  end

  defp persist_dashboard_chat_message(_scope, nil, _role, _content), do: :ok

  defp persist_dashboard_chat_message(scope, session_id, role, content) do
    Ai.create_chat_message(scope, %{chat_session_id: session_id, role: role, content: content})
    :ok
  end

  defp load_dashboard_chat_history(scope, dashboard_id) do
    case Ai.get_chat_session_by_context(scope, :dashboard, dashboard_id) do
      {:ok, session} ->
        messages = Enum.map(session.chat_messages, &%{role: &1.role, content: &1.content})
        {messages, session.id}

      {:error, :not_found} ->
        {[], nil}
    end
  end

  defp extract_chat_named_sources(%{"data" => %{"name" => name}}), do: [name]

  # Story 74: an A2UI component binds to a metric via "query" rather than
  # Vega-Lite's named "data" source -- stashed as the vega_spec field for
  # a chat-built widget so chart_metric_key/1 can reach it the same way.
  defp extract_chat_named_sources(%{"query" => %{"metric" => metric}}), do: [metric]

  defp extract_chat_named_sources(%{"layer" => layers}) when is_list(layers) do
    Enum.flat_map(layers, fn
      %{"data" => %{"name" => name}} -> [name]
      _ -> []
    end)
  end

  defp extract_chat_named_sources(_), do: []

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

      metric_name =
        Map.get(vega_spec, "metric_name") || Map.get(vega_spec, "title") || dv.visualization.name

      chart_type =
        Map.get(vega_spec, "chart_type") ||
          a2ui_component_chart_type_or_nil(vega_spec) ||
          extract_chart_type_from_spec(vega_spec)

      %{
        metric_name: metric_name,
        chart_type: chart_type,
        position: dv.position,
        vega_spec: custom_spec(vega_spec)
      }
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

  defp assign_visualizations(socket, visualizations) do
    scope = socket.assigns.current_scope
    date_range = date_range_for(socket.assigns.dashboard_date_range)

    socket
    |> assign(:visualizations, visualizations)
    |> assign(:chart_specs, resolve_chart_specs(visualizations, scope))
    |> assign(:chart_render, resolve_chart_render(visualizations, scope, date_range))
  end

  defp resolve_chart_specs(visualizations, scope) do
    Enum.map(visualizations, fn viz ->
      case Map.get(viz, :vega_spec) do
        nil -> build_chart_spec(viz.metric_name, viz.chart_type, scope)
        spec -> spec
      end
    end)
  end

  # Story 74: "Charts are ECharts"; "data is fetched at render time and never
  # pasted into the spec." Builds the render-time payload for each card
  # straight from its metric key and chart_type -- not from whatever the
  # stored vega_spec's "data" happens to say -- so this works the same for
  # a chat-built widget (named data source, no embedded values) and an
  # older template/library/manual one (embedded values, or none at all).
  defp resolve_chart_render(visualizations, scope, date_range) do
    Enum.map(visualizations, &build_chart_render(&1, scope, date_range))
  end

  # Story 74 (main, live walk of a7ba770): a widget whose query resolves to
  # zero data points in range gets a clear message instead of a silent 0
  # stat or an empty chart -- checked once, ahead of the stat/chart split,
  # so neither branch has to re-derive "no data" on its own.
  defp build_chart_render(viz, scope, date_range) do
    case query_metric_values(viz, scope, date_range) do
      [] -> {:no_data, nil}
      values -> render_chart_from_values(viz, values)
    end
  end

  defp render_chart_from_values(%{chart_type: "text"}, values) do
    total = Enum.reduce(values, 0, fn {_date, value}, acc -> acc + value end)
    {:stat, format_stat_value(total)}
  end

  defp render_chart_from_values(viz, values) do
    option = %{
      "xAxis" => %{"type" => "category", "data" => Enum.map(values, &elem(&1, 0))},
      "yAxis" => %{"type" => "value"},
      "series" => [echarts_series(viz.chart_type, Enum.map(values, &elem(&1, 1)))]
    }

    {:chart, option}
  end

  # Main's live walk (a7ba770): a stat tile's total should read like
  # "125,706", not a raw float's "125706.0".
  defp format_stat_value(value) do
    value
    |> round()
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  # A template/library-inserted visualization carries no :vega_spec key at
  # all (not even nil) -- Map.get, not a struct-shaped match, so both that
  # and an explicit nil fall through to the plain metric_name.
  defp chart_metric_key(%{metric_name: metric_name} = viz) do
    case Map.get(viz, :vega_spec) do
      nil -> metric_name
      vega_spec ->
        case extract_chat_named_sources(vega_spec) do
          [name | _] -> name
          [] -> metric_name
        end
    end
  end

  defp query_metric_values(viz, scope, date_range) do
    scope
    |> Metrics.query_time_series(chart_metric_key(viz), date_range: date_range)
    |> Enum.map(fn %{date: date, value: value} -> {Date.to_iso8601(date), value} end)
  end

  # Main's live walk (a7ba770 + seeds): the filter's chosen "7"/"30"/"90"
  # range must actually change what's queried, not just its own label --
  # reuses the same presets available_date_ranges/0 already defines for
  # the filter UI elsewhere, so the two can never drift apart.
  defp date_range_for(range_str) do
    key =
      case range_str do
        "7" -> :last_7_days
        "90" -> :last_90_days
        _ -> :last_30_days
      end

    Dashboards.available_date_ranges()
    |> Enum.find(&(&1.key == key))
    |> Map.fetch!(:range)
  end

  defp echarts_series("bar", data), do: %{"type" => "bar", "data" => data}
  defp echarts_series("area", data), do: %{"type" => "line", "data" => data, "areaStyle" => %{}}
  defp echarts_series(_, data), do: %{"type" => "line", "data" => data}

  # A stored vega_spec in the plain `%{"metric_name" => _, "chart_type" => _}` shape is an
  # ad-hoc entry meant to be regenerated live from current metric data on every load, as it
  # always has been. Anything with more keys is a real frozen Vega-Lite spec -- from the
  # library-insert or manual-spec-edit paths -- and must be preserved verbatim.
  defp custom_spec(vega_spec) do
    if Map.keys(vega_spec) -- ["metric_name", "chart_type"] == [] do
      nil
    else
      vega_spec
    end
  end

  defp extract_chart_type_from_spec(%{"mark" => mark}) when is_binary(mark), do: mark
  defp extract_chart_type_from_spec(%{"mark" => %{"type" => type}}) when is_binary(type), do: type
  defp extract_chart_type_from_spec(_), do: "line"

  defp build_chart_spec(metric_name, chart_type, scope) do
    {start_date, end_date} = Dashboards.default_date_range()

    values =
      scope
      |> Metrics.query_time_series(metric_name, date_range: {start_date, end_date})
      |> Enum.map(fn %{date: date, value: value} ->
        %{"date" => Date.to_iso8601(date), "value" => value}
      end)

    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "width" => "container",
      "height" => 100,
      "mark" => chart_type,
      "encoding" => %{
        "x" => %{"field" => "date", "type" => "temporal"},
        "y" => %{"field" => "value", "type" => "quantitative"}
      },
      "data" => %{"values" => values}
    }
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

  defp move_at(list, from, to)
       when from >= 0 and to >= 0 and from < length(list) and to < length(list) and from != to do
    elem = Enum.at(list, from)

    list
    |> List.delete_at(from)
    |> List.insert_at(to, elem)
    |> renumber_positions()
  end

  defp move_at(list, _from, _to), do: list
end
