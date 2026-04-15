defmodule MetricFlowWeb.AiLive.ReportGenerator do
  @moduledoc """
  LiveView for natural language report generation.

  Allows authenticated users to describe a visualization in plain language,
  generate a Vega-Lite chart spec via the AI context, preview the rendered
  chart, and optionally save it as a named visualization.

  Unauthenticated requests are redirected to `/users/log-in` by the router's
  `:require_authenticated_user` pipeline.

  Route: GET /reports/generate
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Ai
  alias MetricFlow.Dashboards

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
      <%!-- Page header --%>
      <h1 class="text-2xl font-bold">Generate Report</h1>
      <p class="text-base-content/60 mt-1">
        Describe the chart or report you want and AI will build it for you.
      </p>

      <%!-- Prompt form --%>
      <div data-role="prompt-form" class="mf-card p-5 mb-6 mt-6">
        <form phx-submit="generate" phx-change="update_prompt">
          <label class="font-semibold text-sm block mb-2">
            What do you want to visualize?
          </label>
          <textarea
            name="prompt"
            data-role="prompt-input"
            rows="4"
            placeholder="e.g. Show me weekly revenue and ad spend over the last 90 days"
            disabled={@generating}
            class="textarea textarea-bordered w-full"
          >{@prompt}</textarea>

          <p
            :if={@error}
            data-role="generate-error"
            class="text-error text-sm mt-2"
          >
            {@error}
          </p>

          <button
            type="submit"
            data-role="generate-btn"
            disabled={@generating || String.trim(@prompt) == ""}
            class={[
              "btn btn-primary mt-4 w-full sm:w-auto",
              (@generating || String.trim(@prompt) == "") && "btn-disabled"
            ]}
          >
            <span :if={@generating} class="loading loading-spinner loading-xs"></span>
            <span :if={@generating}>Generating…</span>
            <span :if={!@generating}>Generate Chart</span>
          </button>
        </form>
      </div>

      <%!-- Chart preview section — shown only when vega_spec is present --%>
      <div :if={@vega_spec} data-role="chart-preview-section" class="mf-card p-5 mb-6">
        <div class="flex items-center justify-between mb-4">
          <span class="font-semibold text-sm">Chart Preview</span>
          <span class="text-xs text-base-content/40">AI-generated — review before saving</span>
        </div>
        <div
          id="report-generator-chart"
          data-role="vega-lite-chart"
          phx-hook="VegaLite"
          data-spec={Jason.encode!(@vega_spec)}
          class="w-full"
        >
        </div>
      </div>

      <%!-- Save section — shown only when vega_spec is present and not yet saved --%>
      <div :if={@vega_spec && !@saved} data-role="save-section" class="mf-card p-5 mb-6">
        <form phx-change="update_save_name" phx-submit="save_visualization">
          <label class="font-semibold text-sm block">Save this visualization</label>
          <input
            type="text"
            name="save_name"
            data-role="save-name-input"
            placeholder="Visualization name"
            value={@save_name}
            class={[
              "input input-bordered w-full mt-2",
              @save_error && "input-error"
            ]}
          />
          <p :if={@save_error} data-role="save-error" class="text-error text-sm mt-1">
            {@save_error}
          </p>
          <button
            type="submit"
            data-role="save-visualization-btn"
            disabled={@saving || is_nil(@vega_spec) || String.trim(@save_name) == ""}
            class={[
              "btn btn-primary btn-sm mt-3 w-full sm:w-auto",
              (@saving || is_nil(@vega_spec) || String.trim(@save_name) == "") && "btn-disabled"
            ]}
          >
            <span :if={@saving} class="loading loading-spinner loading-xs"></span>
            <span :if={@saving}>Saving…</span>
            <span :if={!@saving}>Save Visualization</span>
          </button>
        </form>
      </div>

      <%!-- Save confirmation — shown only when saved is true --%>
      <div :if={@saved} data-role="save-confirmation" class="mf-card p-5 mb-6">
        <div class="flex items-center gap-2 mb-3">
          <span class="badge badge-success">Saved</span>
          <span>Visualization saved!</span>
        </div>
        <.link navigate="/app/visualizations" class="link block mb-3">
          View in Visualizations
        </.link>
        <button
          phx-click="generate_another"
          class="btn btn-ghost btn-sm"
        >
          Generate Another
        </button>
      </div>

      <%!-- Empty / initial state --%>
      <div
        :if={is_nil(@vega_spec) && !@generating && is_nil(@error)}
        data-role="empty-state"
      >
        <p class="text-base-content/40 text-sm text-center py-8">
          Enter a prompt above and click Generate Chart to get started.
        </p>
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
    socket =
      socket
      |> assign(:prompt, "")
      |> assign(:generating, false)
      |> assign(:vega_spec, nil)
      |> assign(:error, nil)
      |> assign(:save_name, "")
      |> assign(:saving, false)
      |> assign(:save_error, nil)
      |> assign(:saved, false)
      |> assign(:page_title, "Generate Report")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Handle params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(_params, _uri, socket) do
    socket =
      socket
      |> assign(:prompt, "")
      |> assign(:generating, false)
      |> assign(:vega_spec, nil)
      |> assign(:error, nil)
      |> assign(:save_name, "")
      |> assign(:saving, false)
      |> assign(:save_error, nil)
      |> assign(:saved, false)

    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("update_prompt", %{"prompt" => prompt}, socket) do
    {:noreply, assign(socket, prompt: prompt, error: nil)}
  end

  def handle_event("generate", _params, %{assigns: %{generating: true}} = socket) do
    {:noreply, socket}
  end

  def handle_event("generate", %{"prompt" => prompt}, socket) do
    case String.trim(prompt) do
      "" ->
        {:noreply, socket}

      trimmed ->
        socket =
          socket
          |> assign(:generating, true)
          |> assign(:vega_spec, nil)
          |> assign(:error, nil)
          |> assign(:saved, false)
          |> assign(:save_name, "")

        scope = socket.assigns.current_scope

        req_opts = Application.get_env(:metric_flow, :req_http_options, [])

        socket =
          case Ai.generate_vega_spec(scope, trimmed, req_http_options: req_opts) do
            {:ok, spec} ->
              socket
              |> assign(:vega_spec, spec)
              |> assign(:generating, false)

            {:error, reason} ->
              socket
              |> assign(:generating, false)
              |> assign(:error, generation_error_message(reason))
          end

        {:noreply, socket}
    end
  end

  def handle_event("update_save_name", %{"save_name" => name}, socket) do
    {:noreply, assign(socket, save_name: name, save_error: nil)}
  end

  def handle_event("save_visualization", params, socket) do
    # Accept save_name from form submit params or fall back to assigns
    save_name = Map.get(params, "save_name", socket.assigns.save_name)
    vega_spec = socket.assigns.vega_spec

    with :ok <- validate_save_name(save_name),
         :ok <- validate_vega_spec_present(vega_spec) do
      do_save_visualization(socket, save_name, vega_spec)
    else
      {:error, :save_name_blank} ->
        {:noreply, assign(socket, :save_error, "Name is required.")}

      {:error, :no_vega_spec} ->
        {:noreply, assign(socket, :save_error, "Generate a chart before saving.")}
    end
  end

  def handle_event("generate_another", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/app/reports/generate")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp validate_save_name(name) when is_binary(name) do
    case String.trim(name) do
      "" -> {:error, :save_name_blank}
      _ -> :ok
    end
  end

  defp validate_save_name(_), do: {:error, :save_name_blank}

  defp validate_vega_spec_present(nil), do: {:error, :no_vega_spec}
  defp validate_vega_spec_present(_spec), do: :ok

  defp do_save_visualization(socket, save_name, vega_spec) do
    scope = socket.assigns.current_scope

    attrs = %{
      name: save_name,
      vega_spec: vega_spec,
      chart_type: "custom",
      shareable: false
    }

    socket = assign(socket, :saving, true)

    case Dashboards.save_visualization(scope, attrs) do
      {:ok, _visualization} ->
        {:noreply, assign(socket, saved: true, saving: false, save_error: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, saving: false, save_error: save_error_from_changeset(changeset))}
    end
  end

  defp save_error_from_changeset(%Ecto.Changeset{} = changeset) do
    Enum.map_join(changeset.errors, ", ", fn {field, {msg, opts}} ->
      "#{field} #{translate_error(msg, opts)}"
    end)
  end

  defp translate_error(msg, opts) do
    if count = opts[:count] do
      Gettext.dngettext(MetricFlowWeb.Gettext, "errors", msg, msg, count, opts)
    else
      Gettext.dgettext(MetricFlowWeb.Gettext, "errors", msg, opts)
    end
  end

  defp generation_error_message(:timeout), do: "The request timed out. Please try again."

  defp generation_error_message(:invalid_spec),
    do: "The AI returned an invalid chart specification. Please try a different prompt."

  defp generation_error_message(_reason),
    do: "Something went wrong generating the chart. Please try again."
end
