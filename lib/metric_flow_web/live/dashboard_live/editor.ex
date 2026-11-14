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

  import MetricFlowWeb.DashboardLive.Components

  alias MetricFlow.Accounts.Authorization
  alias MetricFlow.Ai
  alias MetricFlow.Ai.DashboardBuilder
  alias MetricFlow.Dashboards
  alias MetricFlow.Dashboards.A2ui
  alias MetricFlow.Dashboards.Dashboard

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
                class={[
                  "btn btn-primary btn-sm self-end",
                  @dashboard_chat_generating && "btn-disabled"
                ]}
              >
                <span :if={@dashboard_chat_generating} class="loading loading-spinner loading-xs" />
                <span :if={!@dashboard_chat_generating}>Send</span>
              </button>
            </div>
            <p
              :if={@dashboard_chat_error}
              class="text-error text-xs mt-1"
              data-role="dashboard-chat-error"
            >
              {@dashboard_chat_error}
            </p>
          </form>
        </div>

        <%!-- Versions (Story 74, rule 7: every agent change is a restorable version) --%>
        <div
          :if={@dashboard_versions != []}
          data-role="dashboard-version-list"
          class="mf-card p-4 mb-6"
        >
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

        <%!-- Story 74, rule 5: an interactive control, bound to the
             dashboard's data model like the date range -- only re-runs
             what's shown, never writes anywhere else. --%>
        <.platform_filter
          available_platforms={@available_platforms}
          selected_platform={@dashboard_platform_filter}
        />

        <%!-- Visualization canvas --%>
        <div
          id="visualization-canvas"
          data-role="visualization-canvas"
          class="space-y-4 mb-6"
        >
          <div :if={@visualizations == []} data-role="empty-canvas" class="mf-card p-8 text-center">
            <p class="text-base-content/60">Add a visualization to get started</p>
          </div>

          <.widget_card
            :for={{viz, idx} <- Enum.with_index(@visualizations)}
            chart_id={"dashboard-chart-#{idx}"}
            title={viz.metric_name}
            chart_type={viz.chart_type}
            render={Enum.at(@chart_render, idx)}
          />
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
    account_id = socket.assigns[:active_account_id]

    # Story 75, criterion 1072: only roles with build access may start,
    # edit or delete a dashboard -- a read-only member is refused outright,
    # before any dashboard is created.
    if account_id && !Authorization.can?(scope, :build, %{account_id: account_id}) do
      socket =
        socket
        |> put_flash(:error, "You don't have permission to build dashboards.")
        |> redirect(to: ~p"/app/dashboards")

      {:ok, socket}
    else
      {:ok, socket}
    end
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
        visualizations = visualizations_for_dashboard(dashboard)
        {chat_messages, chat_session_id} = load_dashboard_chat_history(scope, dashboard.id)

        socket =
          socket
          |> assign(:dashboard, dashboard)
          |> assign(:changeset, changeset)
          |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
          |> assign(:available_platforms, A2ui.available_platforms(scope))
          |> assign(:viz_error, nil)
          |> assign(:dashboard_chat_messages, chat_messages)
          |> assign(:dashboard_chat_generating, false)
          |> assign(:dashboard_chat_error, nil)
          |> assign(:dashboard_chat_context, nil)
          |> assign(:dashboard_chat_session_id, chat_session_id)
          |> assign(:dashboard_chat_pending_message, nil)
          |> assign(:dashboard_versions, Dashboards.list_paper_trail_versions(dashboard.id))
          |> assign(:dashboard_date_range, dashboard.date_range || "30")
          |> assign(:dashboard_platform_filter, dashboard.platform_filter)
          |> assign(:page_title, "Edit Dashboard")
          |> assign_visualizations(visualizations)

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
      |> assign(:chart_render, [])
      |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
      |> assign(:available_platforms, A2ui.available_platforms(scope))
      |> assign(:viz_error, nil)
      |> assign(:dashboard_chat_messages, [])
      |> assign(:dashboard_chat_generating, false)
      |> assign(:dashboard_chat_error, nil)
      |> assign(:dashboard_chat_context, nil)
      |> assign(:dashboard_chat_session_id, nil)
      |> assign(:dashboard_chat_pending_message, nil)
      |> assign(:dashboard_versions, [])
      |> assign(:dashboard_date_range, "30")
      |> assign(:dashboard_platform_filter, nil)
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
         assign(
           socket,
           :viz_error,
           "Please add at least one visualization to save the dashboard."
         )}

      _visualizations ->
        do_save(socket)
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
  # looked like then, and the restore itself appears as a new version --
  # both now backed entirely by paper_trail. A version's item_changes only
  # carries a2ui_spec when that version actually touched it (an insert
  # always does; an update does whenever the spec changed); a version with
  # no a2ui_spec in its diff (a rename, a favorite toggle) has nothing to
  # restore from, so it's a no-op rather than guessing.
  def handle_event("restore_version", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    version = Enum.find(socket.assigns.dashboard_versions, &(&1.id == id))

    case version && a2ui_spec_from_version(version) do
      nil -> {:noreply, socket}
      a2ui_spec -> {:noreply, apply_restored_spec(socket, a2ui_spec)}
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

  # Story 74, rule 5: a platform filter is an ordinary interactive control
  # bound to the dashboard's data model, like the date range -- it only
  # re-runs what's shown and saves the chosen value with the dashboard;
  # it never writes anywhere else or calls another tool.
  def handle_event("filter_platform", %{"platform" => "all"}, socket) do
    handle_event("filter_platform", %{"platform" => nil}, socket)
  end

  def handle_event("filter_platform", %{"platform" => platform_str}, socket) do
    platform = platform_str && String.to_existing_atom(platform_str)

    socket =
      socket
      |> assign(:dashboard_platform_filter, platform)
      |> assign_visualizations(socket.assigns.visualizations)

    case socket.assigns.dashboard do
      %Dashboard{} = dashboard ->
        scope = socket.assigns.current_scope

        case Dashboards.update_dashboard(scope, dashboard, %{"platform_filter" => platform_str}) do
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

  def handle_info({ref, {:error, {:unresolvable_metric, names}}}, socket)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    error_msg =
      "I don't have data for #{Enum.join(names, ", ")} yet. Connect that platform in Integrations."

    {:noreply, finish_dashboard_chat_with_error(socket, error_msg)}
  end

  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    require Logger
    Logger.error("dashboard chat error: #{inspect(reason)}")

    {:noreply,
     finish_dashboard_chat_with_error(socket, "The agent couldn't build that. Please try again.")}
  end

  # Reaching here means the task crashed before sending {ref, result} -- a normal
  # completion is already consumed and demonitor-flushed above.
  def handle_info({:DOWN, _ref, :process, _pid, reason}, socket) do
    require Logger
    Logger.error("dashboard chat task crashed: #{inspect(reason)}")

    {:noreply,
     finish_dashboard_chat_with_error(socket, "The AI service is unavailable right now.")}
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
    spec_title = Map.get(a2ui_spec, "title")

    socket
    |> assign_visualizations(visualizations)
    |> autosave_draft_dashboard(
      visualizations,
      spec_title,
      socket.assigns.dashboard_chat_pending_message
    )
  end

  defp visualizations_from_a2ui_spec(%{"components" => components}) do
    components
    |> Enum.with_index()
    |> Enum.map(fn {component, position} ->
      %{
        metric_name: A2ui.component_title(component),
        chart_type: A2ui.component_chart_type(component),
        position: position,
        vega_spec: component
      }
    end)
  end

  defp visualizations_from_a2ui_spec(_a2ui_spec), do: []

  # A paper_trail version's item_changes only carries a2ui_spec when that
  # version actually touched it (an insert always does; an update does
  # whenever the spec changed); a version with no a2ui_spec in its diff
  # (a rename, a favorite toggle) has nothing to restore from.
  defp a2ui_spec_from_version(%{item_changes: changes}), do: Map.get(changes, "a2ui_spec")

  defp apply_restored_spec(socket, a2ui_spec) do
    scope = socket.assigns.current_scope
    dashboard = socket.assigns.dashboard
    visualizations = visualizations_from_a2ui_spec(a2ui_spec)

    case Dashboards.update_dashboard(scope, dashboard, %{"a2ui_spec" => a2ui_spec}) do
      {:ok, dashboard} ->
        socket
        |> assign(:dashboard, dashboard)
        |> assign_visualizations(visualizations)
        |> assign(:dashboard_versions, Dashboards.list_paper_trail_versions(dashboard.id))

      {:error, _} ->
        socket
    end
  end

  # Story 74, rule 1: the first thing the agent builds is saved as a draft
  # with no explicit Save -- once a dashboard already exists we just keep
  # replacing its visualizations on every later build.
  # Story 74, rule 1: the first build saves a draft with no explicit Save.
  # Story 74, rule 7: every later change -- including this first one -- is
  # recorded as a version.
  defp autosave_draft_dashboard(
         %{assigns: %{dashboard: %Dashboard{} = dashboard}} = socket,
         visualizations,
         _spec_title,
         _request_text
       ) do
    scope = socket.assigns.current_scope

    case Dashboards.update_dashboard(scope, dashboard, %{
           "a2ui_spec" => build_a2ui_spec(visualizations)
         }) do
      {:ok, dashboard} ->
        socket
        |> assign(:dashboard, dashboard)
        |> assign(:dashboard_versions, Dashboards.list_paper_trail_versions(dashboard.id))

      {:error, _} ->
        socket
    end
  end

  defp autosave_draft_dashboard(socket, visualizations, spec_title, request_text) do
    scope = socket.assigns.current_scope
    name = draft_dashboard_name(socket.assigns.changeset, spec_title, request_text)
    a2ui_spec = build_a2ui_spec(visualizations)

    case Dashboards.save_dashboard(scope, %{"name" => name, "a2ui_spec" => a2ui_spec}) do
      {:ok, dashboard} ->
        socket
        |> assign(:dashboard, dashboard)
        |> assign(:dashboard_versions, Dashboards.list_paper_trail_versions(dashboard.id))
        |> push_patch(to: ~p"/app/dashboards/#{dashboard.id}/edit")

      {:error, _} ->
        socket
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
      "table" -> base
      chart_type -> Map.put(base, "chartType", chart_type)
    end
  end

  defp a2ui_component_type("text"), do: "stat"
  defp a2ui_component_type("table"), do: "table"
  defp a2ui_component_type(_chart_type), do: "chart"

  # Story 75, criterion 1068: a draft the agent builds (no name typed) is
  # titled from the model's own chosen title (set_dashboard_spec's "title"),
  # not Dana's raw request text -- the request only stands in when the
  # model gives no title at all. An explicitly typed name always wins.
  defp draft_dashboard_name(changeset, spec_title, request_text) do
    case extract_name(changeset) do
      "" -> title_from_spec_or_request(spec_title, request_text)
      name -> name
    end
  end

  defp title_from_spec_or_request(spec_title, request_text) when is_binary(spec_title) do
    case String.trim(spec_title) do
      "" -> title_from_request(request_text)
      trimmed -> trimmed
    end
  end

  defp title_from_spec_or_request(_spec_title, request_text), do: title_from_request(request_text)

  defp title_from_request(nil), do: "Untitled Dashboard"

  defp title_from_request(text) do
    case String.trim(text) do
      "" -> "Untitled Dashboard"
      trimmed -> trimmed |> String.slice(0, 60) |> capitalize_first()
    end
  end

  defp capitalize_first(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest
  defp capitalize_first(str), do: str

  # Story 74, rule 1 again: nothing is persisted for a turn that never builds
  # a dashboard (a failed or declined request leaves no draft to attach
  # history to). Once a dashboard exists, its chat session is created once
  # -- with the dashboard's id already known, so there is no later backfill
  # -- and reused for every later turn.
  defp persist_dashboard_chat_turn(
         %{assigns: %{dashboard: nil}} = socket,
         _user_text,
         _assistant_text
       ),
       do: socket

  defp persist_dashboard_chat_turn(socket, user_text, assistant_text) do
    scope = socket.assigns.current_scope
    {session_id, socket} = ensure_dashboard_chat_session(socket, scope, socket.assigns.dashboard)

    persist_dashboard_chat_message(scope, session_id, :user, user_text)
    persist_dashboard_chat_message(scope, session_id, :assistant, assistant_text)

    socket
  end

  defp ensure_dashboard_chat_session(
         %{assigns: %{dashboard_chat_session_id: id}} = socket,
         _scope,
         _dashboard
       )
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

  # Story 74: chat already autosaves every agent-built change -- this button
  # only persists a typed name. It stops short of touching visualizations
  # or a2ui_spec at all, so it can never stuff a2ui-derived content back
  # into the legacy Visualization/vega_spec rows.
  defp do_save(socket) do
    scope = socket.assigns.current_scope
    name = extract_name(socket.assigns.changeset)
    attrs = %{"name" => name}

    case socket.assigns.dashboard do
      nil ->
        case Dashboards.save_dashboard(scope, attrs) do
          {:ok, dashboard} ->
            {:noreply,
             socket
             |> put_flash(:info, "Dashboard created.")
             |> push_navigate(to: ~p"/app/dashboards/#{dashboard.id}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to save dashboard. Please try again.")}
        end

      dashboard ->
        case Dashboards.update_dashboard(scope, dashboard, attrs) do
          {:ok, updated} ->
            {:noreply,
             socket
             |> put_flash(:info, "Dashboard updated.")
             |> push_navigate(to: ~p"/app/dashboards/#{updated.id}")}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, :changeset, changeset)}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to save dashboard. Please try again.")}
        end
    end
  end

  # Story 74/75: dashboard.a2ui_spec is the single source of truth for an
  # agent-built dashboard. A dashboard saved before a2ui_spec existed has
  # none -- derive its components from its legacy Visualization rows
  # instead, read-only; the next chat turn writes a2ui_spec and this
  # dashboard never needs the legacy path again.
  defp visualizations_for_dashboard(%Dashboard{a2ui_spec: nil} = dashboard) do
    load_visualizations_from_dashboard(dashboard)
  end

  defp visualizations_for_dashboard(%Dashboard{a2ui_spec: a2ui_spec}) do
    visualizations_from_a2ui_spec(a2ui_spec)
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
          A2ui.component_chart_type_or_nil(vega_spec) ||
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
    date_range = socket.assigns.dashboard_date_range
    platform = socket.assigns[:dashboard_platform_filter]

    socket
    |> assign(:visualizations, visualizations)
    |> assign(
      :chart_render,
      Enum.map(
        visualizations,
        &A2ui.build_chart_render(chart_metric_key(&1), &1.chart_type, scope, date_range, platform)
      )
    )
  end

  # A template/library-inserted visualization carries no :vega_spec key at
  # all (not even nil) -- Map.get, not a struct-shaped match, so both that
  # and an explicit nil fall through to the plain metric_name.
  defp chart_metric_key(%{metric_name: metric_name} = viz) do
    case Map.get(viz, :vega_spec) do
      nil ->
        metric_name

      vega_spec ->
        case extract_chat_named_sources(vega_spec) do
          [name | _] -> name
          [] -> metric_name
        end
    end
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
end
