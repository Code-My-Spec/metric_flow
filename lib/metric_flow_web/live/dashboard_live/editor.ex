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
  alias MetricFlow.Ai.VizChat
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
        <select
          id="dashboard-date-range"
          name="range"
          phx-change="filter_date_range"
          class="select select-sm select-bordered"
        >
          <option value="7" selected={@dashboard_date_range == "7"}>Last 7 days</option>
          <option value="30" selected={@dashboard_date_range == "30"}>Last 30 days</option>
          <option value="90" selected={@dashboard_date_range == "90"}>Last 90 days</option>
        </select>
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
              <button
                phx-click="toggle_card_spec_panel"
                phx-value-index={idx}
                data-role="open-spec-panel"
                aria-label="Edit spec"
                class="btn btn-ghost btn-xs"
              >
                Edit Spec
              </button>
            </div>
          </div>

          <div data-role="chart-preview" class="mt-2 h-32 bg-base-200 rounded overflow-hidden">
            <div
              id={"dashboard-chart-#{idx}"}
              data-role="vega-lite-chart"
              phx-hook="VegaLite"
              data-spec={Jason.encode!(Enum.at(@chart_specs, idx))}
              class="w-full h-full"
            >
            </div>
          </div>

          <div :if={@spec_panel_open_index == idx} data-role="spec-panel" class="mt-2">
            <textarea
              name="vega_spec"
              data-role="vega-spec-textarea"
              phx-blur="update_card_spec"
              phx-value-index={idx}
              class={[
                "textarea textarea-bordered w-full font-mono text-xs min-h-[150px]",
                @spec_error && "textarea-error"
              ]}
            >{Jason.encode!(Enum.at(@chart_specs, idx))}</textarea>
            <p :if={@spec_error} class="text-sm text-error mt-1">{@spec_error}</p>
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
          |> assign(:picker_open, false)
          |> assign(:picker_selected_metric, nil)
          |> assign(:picker_selected_chart_type, "line")
          |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
          |> assign(:templates, @templates)
          |> assign(:selected_template, nil)
          |> assign(:chart_types, @chart_types)
          |> assign(:viz_error, nil)
          |> assign(:library_visualizations, Dashboards.list_visualizations(scope))
          |> assign(:spec_panel_open_index, nil)
          |> assign(:spec_error, nil)
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
      |> assign(:picker_open, false)
      |> assign(:picker_selected_metric, nil)
      |> assign(:picker_selected_chart_type, "line")
      |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
      |> assign(:templates, @templates)
      |> assign(:selected_template, nil)
      |> assign(:chart_types, @chart_types)
      |> assign(:viz_error, nil)
      |> assign(:library_visualizations, Dashboards.list_visualizations(scope))
      |> assign(:spec_panel_open_index, nil)
      |> assign(:spec_error, nil)
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
      |> assign(:chart_specs, resolve_chart_specs(visualizations, scope))
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
          |> assign(:picker_open, false)
          |> assign(:viz_error, nil)

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Visualization not found.")}
    end
  end

  def handle_event("toggle_card_spec_panel", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    current = socket.assigns.spec_panel_open_index
    new_index = if current == index, do: nil, else: index

    {:noreply, assign(socket, spec_panel_open_index: new_index, spec_error: nil)}
  end

  def handle_event("update_card_spec", %{"index" => index_str, "value" => json}, socket) do
    index = String.to_integer(index_str)

    case Jason.decode(json) do
      {:ok, spec} when is_map(spec) ->
        visualizations =
          List.update_at(socket.assigns.visualizations, index, &Map.put(&1, :vega_spec, spec))

        chart_specs = List.replace_at(socket.assigns.chart_specs, index, spec)

        socket =
          socket
          |> assign(:visualizations, visualizations)
          |> assign(:chart_specs, chart_specs)
          |> assign(:spec_error, nil)

        {:noreply, socket}

      {:ok, _} ->
        {:noreply, assign(socket, :spec_error, "Spec must be a JSON object")}

      {:error, _} ->
        {:noreply, assign(socket, :spec_error, "Invalid JSON")}
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

        case Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations) do
          :ok ->
            socket =
              socket
              |> assign_visualizations(visualizations)
              |> record_dashboard_version(dashboard, visualizations)

            {:noreply, socket}

          {:error, _} ->
            {:noreply, socket}
        end
    end
  end

  # Story 74, rule 5: changing the range only re-runs what is shown, not a
  # model/tool call. Rule 8: the chosen value is saved with the dashboard
  # itself so it survives a reopen -- there's nothing to save yet for a
  # dashboard the agent hasn't built anything on.
  def handle_event("filter_date_range", %{"range" => range}, socket) do
    socket = assign(socket, :dashboard_date_range, range)

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
  def handle_info({ref, {:ok, %{text: text, specs: specs, context: updated_context}}}, socket)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    user_text = socket.assigns.dashboard_chat_pending_message
    assistant_msg = %{role: :assistant, content: text}

    socket =
      socket
      |> append_chat_message(assistant_msg)
      |> assign(:dashboard_chat_context, updated_context)
      |> assign(:dashboard_chat_generating, false)
      |> add_visualizations_from_chat_specs(specs)
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
        current_spec = existing_widgets_context(socket.assigns.chart_specs)
        runner = Application.get_env(:metric_flow, :command_runner)

        Task.async(fn ->
          VizChat.send_message(
            context,
            trimmed,
            metric_names: metric_names,
            command_runner: runner,
            multi_widget: true,
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

  # Story 74 rule 4: a message sent on an already-built dashboard (fresh
  # /new build or a reopened one via "Edit with agent") should tell the
  # model what is already there, so it can refine or add to it rather than
  # acting as if nothing exists.
  defp existing_widgets_context([]), do: nil
  defp existing_widgets_context(chart_specs), do: %{"existing_widgets" => chart_specs}

  defp append_chat_message(socket, message) do
    assign(socket, :dashboard_chat_messages, socket.assigns.dashboard_chat_messages ++ [message])
  end

  defp finish_dashboard_chat_with_error(socket, error_msg) do
    socket
    |> append_chat_message(%{role: :assistant, content: "Error: #{error_msg}"})
    |> assign(:dashboard_chat_generating, false)
    |> assign(:dashboard_chat_error, error_msg)
  end

  defp add_visualizations_from_chat_specs(socket, []), do: socket

  defp add_visualizations_from_chat_specs(socket, specs) do
    start_position = length(socket.assigns.visualizations)

    new_vizzes =
      specs
      |> Enum.with_index(start_position)
      |> Enum.map(fn {spec, position} ->
        %{
          metric_name: extract_chat_metric_name(spec),
          chart_type: extract_chart_type_from_spec(spec),
          position: position,
          vega_spec: custom_spec(spec)
        }
      end)

    visualizations = socket.assigns.visualizations ++ new_vizzes

    socket
    |> assign_visualizations(visualizations)
    |> autosave_draft_dashboard(visualizations)
  end

  # Story 74, rule 1: the first thing the agent builds is saved as a draft
  # with no explicit Save -- once a dashboard already exists we just keep
  # replacing its visualizations on every later build.
  # Story 74, rule 1: the first build saves a draft with no explicit Save.
  # Story 74, rule 7: every later change -- including this first one -- is
  # recorded as a version.
  defp autosave_draft_dashboard(%{assigns: %{dashboard: %Dashboard{} = dashboard}} = socket, visualizations) do
    scope = socket.assigns.current_scope

    case Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations) do
      :ok -> record_dashboard_version(socket, dashboard, visualizations)
      {:error, _} -> socket
    end
  end

  defp autosave_draft_dashboard(socket, visualizations) do
    scope = socket.assigns.current_scope
    name = draft_dashboard_name(socket.assigns.changeset)

    with {:ok, dashboard} <- Dashboards.save_dashboard(scope, %{"name" => name}),
         :ok <- Dashboards.replace_dashboard_visualizations(scope, dashboard, visualizations) do
      socket
      |> assign(:dashboard, dashboard)
      |> record_dashboard_version(dashboard, visualizations)
      |> push_patch(to: ~p"/app/dashboards/#{dashboard.id}/edit")
    else
      _ -> socket
    end
  end

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

  defp extract_chat_metric_name(%{"title" => title}) when is_binary(title), do: title

  defp extract_chat_metric_name(spec) do
    case extract_chat_named_sources(spec) do
      [name | _] -> name
      [] -> "Custom"
    end
  end

  defp extract_chat_named_sources(%{"data" => %{"name" => name}}), do: [name]

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
      metric_name = Map.get(vega_spec, "metric_name") || dv.visualization.name

      chart_type =
        Map.get(vega_spec, "chart_type") || extract_chart_type_from_spec(vega_spec)

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

    socket
    |> assign(:visualizations, visualizations)
    |> assign(:chart_specs, resolve_chart_specs(visualizations, scope))
  end

  defp resolve_chart_specs(visualizations, scope) do
    Enum.map(visualizations, fn viz ->
      case Map.get(viz, :vega_spec) do
        nil -> build_chart_spec(viz.metric_name, viz.chart_type, scope)
        spec -> spec
      end
    end)
  end

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
