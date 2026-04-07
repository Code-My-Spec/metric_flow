defmodule MetricFlowWeb.CorrelationLive.Goals do
  @moduledoc """
  LiveView for configuring the goal metric used by the correlation engine.

  Allows an authenticated user to select which metric serves as the goal metric
  against which all other metrics are correlated. Pre-selects the most recent
  goal from the latest correlation summary when available.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Correlations
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
    <div class="max-w-2xl mx-auto mf-content px-4 py-8">
      <%!-- Page header --%>
      <div class="mb-6">
        <h1 class="text-2xl font-bold">Goal Metric</h1>
        <p class="text-base-content/60">Choose the metric the correlation engine targets.</p>
      </div>

      <%!-- Empty state (shown above form when no metrics available) --%>
      <div :if={@metric_names == []} class="mf-card p-6 mb-6">
        <p class="text-base-content/60">
          No metrics available. Connect your integrations and sync data before configuring a goal.
        </p>
        <.link navigate={~p"/app/integrations"} class="btn btn-primary mt-4">
          Connect Integrations
        </.link>
      </div>

      <%!-- Goal metric form --%>
      <.form for={%{}} phx-submit="save_goal">
        <div class="mf-card p-6">
          <div class="form-control">
            <label class="label">
              <span class="label-text font-medium">Goal Metric</span>
            </label>
            <select
              name="goal_metric_name"
              phx-change="select_goal"
              class="select select-bordered w-full"
              disabled={@metric_names == []}
            >
              <option :if={@metric_names == []} value="" disabled>
                No metrics available — sync data first
              </option>
              <option
                :for={name <- @metric_names}
                value={name}
                selected={name == @selected_goal}
              >
                {name}
              </option>
            </select>
          </div>

          <div class="flex gap-2 mt-6">
            <button
              type="submit"
              data-role="save-goal"
              disabled={@metric_names == []}
              class="btn btn-primary"
            >
              Save Goal
            </button>
            <button
              type="button"
              phx-click="cancel"
              data-role="cancel"
              class="btn btn-ghost"
            >
              Cancel
            </button>
          </div>
        </div>
      </.form>
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

    metric_names = Metrics.list_metric_names(scope)
    summary = Correlations.get_latest_correlation_summary(scope)

    selected_goal = determine_selected_goal(summary, metric_names)

    socket =
      socket
      |> assign(:metric_names, metric_names)
      |> assign(:selected_goal, selected_goal)
      |> assign(:page_title, "Goal Metric")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("select_goal", %{"goal_metric_name" => metric_name}, socket) do
    {:noreply, assign(socket, :selected_goal, metric_name)}
  end

  def handle_event("save_goal", params, socket) do
    metric_names = socket.assigns.metric_names
    scope = socket.assigns.current_scope
    selected_goal = resolve_goal(params, socket.assigns.selected_goal)

    case validate_goal(selected_goal, metric_names) do
      :ok ->
        handle_run_correlations(scope, selected_goal, socket)

      {:error, :empty} ->
        {:noreply, put_flash(socket, :error, "Please select a goal metric.")}
    end
  end

  def handle_event("cancel", _params, socket) do
    {:noreply, push_navigate(socket, to: ~p"/app/correlations")}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp resolve_goal(%{"goal_metric_name" => value}, _assign) when value != "", do: value
  defp resolve_goal(%{"goal_metric_name" => ""}, _assign), do: ""
  defp resolve_goal(_params, assign), do: assign

  defp determine_selected_goal(%{goal_metric_name: name}, _metric_names) when is_binary(name),
    do: name

  defp determine_selected_goal(_summary, [first | _rest]), do: first
  defp determine_selected_goal(_summary, []), do: ""

  defp validate_goal("", _metric_names), do: {:error, :empty}
  defp validate_goal(nil, _metric_names), do: {:error, :empty}

  defp validate_goal(goal, metric_names) do
    if goal in metric_names do
      :ok
    else
      {:error, :empty}
    end
  end

  defp handle_run_correlations(scope, selected_goal, socket) do
    case Correlations.run_correlations(scope, %{goal_metric_name: selected_goal}) do
      {:ok, _job} ->
        socket =
          socket
          |> put_flash(:info, "Goal metric saved. Correlation analysis started.")
          |> push_navigate(to: ~p"/app/correlations")

        {:noreply, socket}

      {:error, :already_running} ->
        socket =
          socket
          |> put_flash(:info, "A correlation run is already in progress.")
          |> push_navigate(to: ~p"/app/correlations")

        {:noreply, socket}

      {:error, :insufficient_data} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Not enough data — at least 30 days of metrics required."
         )}
    end
  end
end
