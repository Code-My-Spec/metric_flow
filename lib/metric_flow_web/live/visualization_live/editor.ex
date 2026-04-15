defmodule MetricFlowWeb.VisualizationLive.Editor do
  @moduledoc """
  LiveView for creating and editing visualizations with a three-panel workspace.

  Layout: collapsible spec editor (left) | chart preview (center) | collapsible LLM chat (right)

  Users can build charts by selecting metrics, editing the Vega-Lite JSON spec
  directly, or using natural language via the LLM chat panel. All three panels
  stay in sync — LLM-generated specs update the editor and preview, and manual
  spec edits update the preview without an LLM round-trip.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Ai
  alias MetricFlow.Dashboards
  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Metrics

  @chart_types ["line", "bar", "area", "point", "arc", "rect"]

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
      <div class="flex h-full" data-role="visualization-workspace">
        <%!-- Left: Spec editor drawer --%>
        <div class="flex flex-shrink-0 border-r border-base-300" data-role="spec-panel">
          <div
            :if={@left_panel_open}
            id="spec-panel-content"
            class="w-88 flex flex-col bg-base-100 overflow-hidden"
          >
            <div class="flex-1 overflow-y-auto p-3">
              <textarea
                name="vega_spec"
                data-role="vega-spec-textarea"
                phx-blur="update_vega_spec"
                class={[
                  "textarea textarea-bordered w-full h-full font-mono text-xs resize-none min-h-[200px]",
                  @spec_error && "textarea-error"
                ]}
              >{@raw_vega_spec}</textarea>
              <p :if={@spec_error} class="text-sm text-error mt-1">{@spec_error}</p>
            </div>
          </div>
          <div
            :if={@left_panel_open}
            id="spec-resize-handle"
            phx-hook="ResizablePanel"
            data-target="#spec-panel-content"
            data-direction="left"
            data-min-width="200"
            data-max-width="700"
            class="w-1 cursor-col-resize bg-base-300 hover:bg-primary/40 transition-colors flex-shrink-0"
          />
          <button
            phx-click="toggle_left_panel"
            data-role="open-spec-panel"
            class="w-8 flex items-center justify-center cursor-pointer bg-base-200 hover:bg-base-300 transition-colors"
          >
            <span class="[writing-mode:vertical-lr] rotate-180 text-xs font-semibold text-base-content/70 tracking-wider py-4">
              Spec Editor
            </span>
          </button>
        </div>

        <%!-- Center: Chart preview + controls --%>
        <div class="flex-1 flex flex-col overflow-hidden">
          <%!-- Toolbar --%>
          <div class="flex items-center gap-2 px-4 py-2 border-b border-base-300 flex-wrap">
            <%!-- Name --%>
            <form phx-change="validate_name" class="flex-shrink-0">
              <input
                type="text"
                name="name"
                value={@name}
                data-role="visualization-name-input"
                placeholder="Untitled Visualization"
                class={["input input-bordered input-sm w-56", @name_error && "input-error"]}
              />
            </form>

            <%!-- Metric selector --%>
            <div class="dropdown" data-role="metric-selector">
              <div tabindex="0" role="button" class="btn btn-ghost btn-sm">
                {if @selected_metric, do: @selected_metric, else: "Select Metric"}
              </div>
              <ul
                :if={@available_metrics != []}
                tabindex="-1"
                data-role="metric-list"
                class="dropdown-content menu bg-base-200 rounded-box z-10 w-64 p-2 shadow max-h-60 overflow-y-auto"
              >
                <li :for={metric <- @available_metrics}>
                  <a phx-click="select_metric" phx-value-metric={metric}>{metric}</a>
                </li>
              </ul>
            </div>

            <%!-- Chart type --%>
            <div class="flex items-center gap-1" data-role="chart-type-selector">
              <button
                :for={type <- @chart_types}
                phx-click="select_chart_type"
                phx-value-chart_type={type}
                class={[
                  "btn btn-xs",
                  @selected_chart_type == type && "btn-primary",
                  @selected_chart_type != type && "btn-ghost"
                ]}
              >
                {String.capitalize(type)}
              </button>
            </div>

            <div class="flex-1" />

            <%!-- Shareable toggle --%>
            <button
              phx-click="toggle_shareable"
              data-role="toggle-shareable"
              class={["btn btn-xs", @shareable && "btn-primary", !@shareable && "btn-ghost"]}
            >
              Shareable
            </button>

            <%!-- Save --%>
            <button
              phx-click="save_visualization"
              data-role="save-visualization-btn"
              class="btn btn-primary btn-sm"
            >
              Save
            </button>

          </div>

          <%!-- Error bar --%>
          <p :if={@name_error} class="text-sm text-error px-4 pt-1">{@name_error}</p>

          <%!-- Chart area --%>
          <div class="flex-1 overflow-auto p-4" data-role="chart-preview-section">
            <div :if={is_nil(@chart_preview)} data-role="chart-placeholder" class="flex items-center justify-center h-full">
              <div class="text-center">
                <p class="text-base-content/60 text-sm">
                  Select a metric or describe a chart in the AI Chat panel.
                </p>
                <div :if={@available_metrics == []} data-role="no-metrics-available" class="mt-4">
                  <p class="text-sm text-base-content/40">No metrics available.</p>
                  <.link navigate="/app/integrations" class="btn btn-ghost btn-sm mt-2">
                    Connect a Platform
                  </.link>
                </div>
              </div>
            </div>

            <div
              :if={not is_nil(@chart_preview)}
              id="visualization-preview-chart"
              data-role="vega-lite-chart"
              phx-hook="VegaLite"
              data-spec={Jason.encode!(@chart_preview)}
              class="w-full h-full"
            >
            </div>
          </div>
        </div>

        <%!-- Right: Chat drawer --%>
        <div class="flex flex-shrink-0 border-l border-base-300" data-role="chat-panel">
          <button
            phx-click="toggle_right_panel"
            data-role="open-chat-panel"
            class="w-8 flex items-center justify-center cursor-pointer bg-base-200 hover:bg-base-300 transition-colors"
          >
            <span class="[writing-mode:vertical-lr] text-xs font-semibold text-base-content/70 tracking-wider py-4">
              AI Chat
            </span>
          </button>
          <div
            :if={@right_panel_open}
            id="chat-resize-handle"
            phx-hook="ResizablePanel"
            data-target="#chat-panel-content"
            data-direction="right"
            data-min-width="200"
            data-max-width="700"
            class="w-1 cursor-col-resize bg-base-300 hover:bg-primary/40 transition-colors flex-shrink-0"
          />
          <div
            :if={@right_panel_open}
            id="chat-panel-content"
            class="w-88 flex flex-col bg-base-100 overflow-hidden"
          >

          <%!-- Chat messages --%>
          <div
            id="chat-messages"
            data-role="chat-messages"
            class="flex-1 overflow-y-auto p-3 space-y-3"
            phx-update="stream"
          >
            <div
              :for={{dom_id, msg} <- @streams.chat_messages}
              id={dom_id}
              class={[
                "p-3 rounded-lg text-sm",
                msg.role == :user && "bg-primary/10 ml-6",
                msg.role == :assistant && "bg-base-200 mr-6"
              ]}
            >
              <p class="font-semibold text-xs mb-1 text-base-content/60">
                {if msg.role == :user, do: "You", else: "AI"}
              </p>
              <p class="whitespace-pre-wrap">{msg.content}</p>
            </div>
          </div>

          <%!-- Chat input --%>
          <div class="border-t border-base-300 p-3">
            <form phx-submit="send_chat" data-role="chat-form">
              <div class="flex gap-2">
                <textarea
                  id="chat-prompt-input"
                  name="prompt"
                  data-role="chat-input"
                  rows="2"
                  placeholder="Describe the chart you want..."
                  disabled={@chat_generating}
                  class="textarea textarea-bordered textarea-sm flex-1 resize-none"
                ></textarea>
                <button
                  type="submit"
                  data-role="chat-send-btn"
                  disabled={@chat_generating}
                  class={[
                    "btn btn-primary btn-sm self-end",
                    @chat_generating && "btn-disabled"
                  ]}
                >
                  <span :if={@chat_generating} class="loading loading-spinner loading-xs" />
                  <span :if={!@chat_generating}>Send</span>
                </button>
              </div>
              <p :if={@chat_error} class="text-error text-xs mt-1" data-role="chat-error">
                {@chat_error}
              </p>
            </form>
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
  # Handle params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    scope = socket.assigns.current_scope
    id_int = String.to_integer(id)

    case Dashboards.get_visualization(scope, id_int) do
      {:ok, visualization} ->
        chart_type = extract_chart_type(visualization.vega_spec)
        bound = Dashboards.get_visualization_metric_names(visualization)

        # Fall back to extracting from spec title for legacy visualizations
        bound =
          if bound == [] do
            case extract_metric_name(visualization.vega_spec) do
              nil -> []
              name -> [name]
            end
          else
            bound
          end

        # Use saved spec as template, resolve named data for preview
        template =
          if bound != [] do
            # Rebuild template from bound metrics (or use saved spec if it has named data)
            saved_spec = visualization.vega_spec || %{}

            if has_named_data?(saved_spec) do
              saved_spec
            else
              build_template_spec(bound, chart_type, visualization.name)
            end
          else
            visualization.vega_spec || %{}
          end

        preview = resolve_named_data(template, scope)

        socket =
          socket
          |> assign_common(scope)
          |> assign(:visualization, visualization)
          |> assign(:name, visualization.name || "")
          |> assign(:selected_metric, List.first(bound))
          |> assign(:selected_chart_type, chart_type || "line")
          |> assign(:shareable, visualization.shareable)
          |> assign(:bound_metrics, bound)
          |> assign(:chart_preview, preview)
          |> assign(:raw_vega_spec, format_spec(template))
          |> assign(:page_title, "Edit Visualization")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Visualization not found.")
         |> redirect(to: "/app/dashboards")}
    end
  end

  def handle_params(_params, _uri, socket) do
    scope = socket.assigns.current_scope

    socket =
      socket
      |> assign_common(scope)
      |> assign(:visualization, nil)
      |> assign(:name, "")
      |> assign(:selected_metric, nil)
      |> assign(:selected_chart_type, "line")
      |> assign(:shareable, false)
      |> assign(:chart_preview, nil)
      |> assign(:raw_vega_spec, "")
      |> assign(:page_title, "New Visualization")

    {:noreply, socket}
  end

  defp assign_common(socket, scope) do
    socket
    |> assign(:name_error, nil)
    |> assign(:spec_error, nil)
    |> assign(:available_metrics, Dashboards.list_available_metrics(scope))
    |> assign(:chart_types, @chart_types)
    |> assign(:left_panel_open, false)
    |> assign(:right_panel_open, true)
    |> assign(:bound_metrics, [])
    |> assign(:chat_generating, false)
    |> assign(:chat_error, nil)
    |> assign(:chat_context, nil)
    |> stream(:chat_messages, [])
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
    scope = socket.assigns.current_scope
    bound = socket.assigns.bound_metrics

    # Add metric to bound list if not already there
    bound = if metric in bound, do: bound, else: bound ++ [metric]

    # Build template (named data sources) then resolve for preview
    template = build_template_spec(bound, socket.assigns.selected_chart_type, socket.assigns.name)
    preview = resolve_named_data(template, scope)

    {:noreply,
     assign(socket,
       selected_metric: metric,
       bound_metrics: bound,
       chart_preview: preview,
       raw_vega_spec: format_spec(template)
     )}
  end

  def handle_event("select_chart_type", %{"chart_type" => type}, socket) do
    socket = assign(socket, :selected_chart_type, type)

    socket =
      if socket.assigns.bound_metrics != [] do
        scope = socket.assigns.current_scope
        template = build_template_spec(socket.assigns.bound_metrics, type, socket.assigns.name)
        preview = resolve_named_data(template, scope)
        assign(socket, chart_preview: preview, raw_vega_spec: format_spec(template))
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_event("toggle_shareable", _params, socket) do
    {:noreply, assign(socket, :shareable, !socket.assigns.shareable)}
  end

  def handle_event("toggle_left_panel", _params, socket) do
    show = !socket.assigns.left_panel_open

    raw =
      if show and socket.assigns.raw_vega_spec == "" do
        format_spec(socket.assigns.chart_preview)
      else
        socket.assigns.raw_vega_spec
      end

    {:noreply, assign(socket, left_panel_open: show, raw_vega_spec: raw)}
  end

  def handle_event("toggle_right_panel", _params, socket) do
    {:noreply, assign(socket, :right_panel_open, !socket.assigns.right_panel_open)}
  end

  def handle_event("update_vega_spec", %{"value" => json}, socket) do
    case Jason.decode(json) do
      {:ok, spec} when is_map(spec) ->
        scope = socket.assigns.current_scope
        # Resolve named data sources so the chart renders with real values
        preview = resolve_named_data(spec, scope)

        # Extract bound metrics from named data in the spec
        bound = extract_named_metrics(spec)

        {:noreply,
         assign(socket,
           raw_vega_spec: json,
           chart_preview: preview,
           spec_error: nil,
           bound_metrics: if(bound != [], do: bound, else: socket.assigns.bound_metrics),
           selected_chart_type: extract_chart_type(spec),
           selected_metric: extract_metric_name(spec)
         )}

      {:ok, _} ->
        {:noreply, assign(socket, raw_vega_spec: json, spec_error: "Spec must be a JSON object")}

      {:error, _} ->
        {:noreply, assign(socket, raw_vega_spec: json, spec_error: "Invalid JSON")}
    end
  end

  def handle_event("send_chat", %{"prompt" => prompt}, socket) do
    case String.trim(prompt) do
      "" ->
        {:noreply, socket}

      trimmed ->
        user_msg = %{role: :user, content: trimmed, id: System.unique_integer([:positive])}

        socket =
          socket
          |> stream_insert(:chat_messages, user_msg)
          |> assign(:chat_generating, true)
          |> assign(:chat_error, nil)

        scope = socket.assigns.current_scope
        req_opts = Application.get_env(:metric_flow, :req_http_options, [])
        chat_context = socket.assigns.chat_context
        current_spec = current_template_spec(socket)
        opts = [req_http_options: req_opts, current_spec: current_spec]

        # Async — don't block the LiveView process
        Task.async(fn ->
          Ai.viz_chat(scope, chat_context, trimmed, opts)
        end)

        {:noreply, socket}
    end
  end

  def handle_event("save_visualization", _params, socket) do
    name = socket.assigns.name
    metric = socket.assigns.selected_metric

    cond do
      name == "" || is_nil(name) ->
        {:noreply, assign(socket, :name_error, "Name is required")}

      is_nil(socket.assigns.chart_preview) ->
        {:noreply, put_flash(socket, :error, "Generate or select a chart before saving.")}

      true ->
        do_save(socket)
    end
  end

  # ---------------------------------------------------------------------------
  # Async viz_chat result handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_info({ref, {:ok, %{text: text, spec: spec, context: updated_context}}}, socket)
      when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    assistant_msg = %{
      role: :assistant,
      content: text,
      id: System.unique_integer([:positive])
    }

    socket =
      socket
      |> stream_insert(:chat_messages, assistant_msg)
      |> assign(:chat_context, updated_context)
      |> assign(:chat_generating, false)

    socket =
      if spec do
        scope = socket.assigns.current_scope
        bound = extract_named_metrics(spec)
        bound = if bound != [], do: bound, else: socket.assigns.bound_metrics
        preview = resolve_named_data(spec, scope)

        assign(socket,
          chart_preview: preview,
          raw_vega_spec: format_spec(spec),
          bound_metrics: bound,
          selected_chart_type: extract_chart_type(spec),
          selected_metric: List.first(bound) || extract_metric_name(spec)
        )
      else
        socket
      end

    {:noreply, socket}
  end

  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])
    require Logger
    Logger.error("viz_chat error: #{inspect(reason)}")
    error_msg = generation_error_message(reason)

    assistant_msg = %{
      role: :assistant,
      content: "Error: #{error_msg}",
      id: System.unique_integer([:positive])
    }

    {:noreply,
     socket
     |> stream_insert(:chat_messages, assistant_msg)
     |> assign(chat_generating: false, chat_error: error_msg)}
  end

  # Task DOWN message — already handled via demonitor flush
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Returns the template spec (with named data sources, no embedded values)
  # for use as LLM context. Falls back to rebuilding from bound metrics.
  defp current_template_spec(socket) do
    bound = socket.assigns.bound_metrics

    cond do
      # Try to parse the raw spec editor content (it should be the template)
      socket.assigns.raw_vega_spec != "" ->
        case Jason.decode(socket.assigns.raw_vega_spec) do
          {:ok, spec} when is_map(spec) -> spec
          _ -> nil
        end

      # Rebuild from bound metrics
      bound != [] ->
        build_template_spec(bound, socket.assigns.selected_chart_type, socket.assigns.name)

      true ->
        nil
    end
  end

  defp do_save(socket) do
    scope = socket.assigns.current_scope
    name = socket.assigns.name
    shareable = socket.assigns.shareable
    metric_names = socket.assigns.bound_metrics

    # Save the template spec (named data sources, no embedded values)
    vega_spec =
      if metric_names != [] do
        build_template_spec(metric_names, socket.assigns.selected_chart_type, socket.assigns.name)
      else
        socket.assigns.chart_preview
      end

    attrs = %{
      name: name,
      shareable: shareable,
      vega_spec: vega_spec
    }

    persist_visualization(socket, scope, socket.assigns.visualization, attrs, metric_names)
  end

  defp persist_visualization(socket, scope, nil, attrs, metric_names) do
    case Dashboards.save_visualization(scope, attrs) do
      {:ok, visualization} ->
        Dashboards.set_visualization_metrics(visualization, metric_names)

        {:noreply,
         socket
         |> assign(:visualization, visualization)
         |> put_flash(:info, "Visualization saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_error, name_error_from_changeset(changeset))}
    end
  end

  defp persist_visualization(socket, scope, %Visualization{} = visualization, attrs, metric_names) do
    case Dashboards.update_visualization(scope, visualization, attrs) do
      {:ok, updated} ->
        Dashboards.set_visualization_metrics(updated, metric_names)

        {:noreply,
         socket
         |> assign(:visualization, updated)
         |> put_flash(:info, "Visualization saved.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :name_error, name_error_from_changeset(changeset))}
    end
  end

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
  defp extract_metric_name(%{"metric_name" => name}) when is_binary(name), do: name
  defp extract_metric_name(_), do: nil

  defp extract_chart_type(%{"mark" => %{"type" => mark}}) when is_binary(mark), do: mark
  defp extract_chart_type(%{"mark" => mark}) when is_binary(mark), do: mark
  defp extract_chart_type(%{"chart_type" => type}) when is_binary(type), do: type
  defp extract_chart_type(_), do: "line"

  defp format_spec(nil), do: ""
  defp format_spec(spec) when is_map(spec), do: Jason.encode!(spec, pretty: true)
  defp format_spec(_), do: ""

  defp fetch_metric_data(scope, metric_name) do
    {start_date, end_date} = Dashboards.default_date_range()
    Metrics.query_time_series(scope, metric_name, date_range: {start_date, end_date})
  end

  # Builds a spec template with named data sources (no embedded values).
  # Single metric: {"data": {"name": "activeUsers"}, ...}
  # Multi metric: {"layer": [{"data": {"name": "activeUsers"}, ...}, ...]}
  defp build_template_spec(metric_names, chart_type, title \\ nil) do
    mark = chart_type || "line"
    title = title || List.first(metric_names) || "Untitled"

    encoding = %{
      "x" => %{"field" => "date", "type" => "temporal"},
      "y" => %{"field" => "value", "type" => "quantitative"}
    }

    base = %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "title" => title,
      "width" => "container",
      "height" => 400,
      "config" => dark_theme()
    }

    case metric_names do
      [single] ->
        Map.merge(base, %{
          "data" => %{"name" => single},
          "mark" => mark,
          "encoding" => encoding
        })

      multiple ->
        layers =
          Enum.map(multiple, fn name ->
            %{
              "data" => %{"name" => name},
              "mark" => %{"type" => mark, "point" => true, "tooltip" => true},
              "encoding" =>
                Map.merge(encoding, %{
                  "color" => %{"datum" => name}
                })
            }
          end)

        Map.put(base, "layer", layers)
    end
  end

  # Resolves named data sources in a spec by fetching real metric data.
  # Replaces {"name": "activeUsers"} with {"values": [...]}
  defp resolve_named_data(spec, scope) do
    {start_date, end_date} = Dashboards.default_date_range()

    cond do
      # Layered spec — resolve each layer's data
      Map.has_key?(spec, "layer") ->
        layers =
          Enum.map(spec["layer"], fn layer ->
            resolve_layer_data(layer, scope, {start_date, end_date})
          end)

        Map.put(spec, "layer", layers)

      # Single data source
      match?(%{"name" => _}, spec["data"]) ->
        name = spec["data"]["name"]
        values = fetch_metric_values(scope, name, {start_date, end_date})
        Map.put(spec, "data", %{"values" => values})

      true ->
        spec
    end
  end

  defp resolve_layer_data(%{"data" => %{"name" => name}} = layer, scope, date_range) do
    values = fetch_metric_values(scope, name, date_range)
    Map.put(layer, "data", %{"values" => values})
  end

  defp resolve_layer_data(layer, _scope, _date_range), do: layer

  defp fetch_metric_values(scope, metric_name, {start_date, end_date}) do
    Metrics.query_time_series(scope, metric_name, date_range: {start_date, end_date})
    |> Enum.map(fn %{date: date, value: value} ->
      %{"date" => Date.to_iso8601(date), "value" => value}
    end)
  end

  defp extract_named_metrics(%{"data" => %{"name" => name}}), do: [name]
  defp extract_named_metrics(%{"layer" => layers}) when is_list(layers) do
    Enum.flat_map(layers, fn
      %{"data" => %{"name" => name}} -> [name]
      _ -> []
    end)
  end
  defp extract_named_metrics(_), do: []

  defp has_named_data?(%{"data" => %{"name" => _}}), do: true
  defp has_named_data?(%{"layer" => layers}) when is_list(layers) do
    Enum.any?(layers, &match?(%{"data" => %{"name" => _}}, &1))
  end
  defp has_named_data?(_), do: false

  defp dark_theme do
    %{
      "background" => "transparent",
      "title" => %{"color" => "#a6adbb"},
      "axis" => %{
        "labelColor" => "#a6adbb",
        "titleColor" => "#a6adbb",
        "gridColor" => "#2a323c",
        "domainColor" => "#3d4451",
        "tickColor" => "#3d4451"
      },
      "legend" => %{"labelColor" => "#a6adbb", "titleColor" => "#a6adbb"},
      "view" => %{"stroke" => "transparent"}
    }
  end

  defp generation_error_message(:no_metrics), do: "No metrics available. Connect a platform first."
  defp generation_error_message(:invalid_spec), do: "AI generated an invalid chart spec. Try rephrasing."
  defp generation_error_message(:api_error), do: "AI service is temporarily unavailable."
  defp generation_error_message(reason) when is_binary(reason), do: reason
  defp generation_error_message(_), do: "Something went wrong. Please try again."
end
