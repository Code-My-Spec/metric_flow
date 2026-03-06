defmodule MetricFlowWeb.AiLive.Insights do
  @moduledoc """
  LiveView for browsing AI-generated insights.

  Displays all insights for the active account with suggestion type filtering
  and helpful/not-helpful feedback. Insights are produced by the AI context
  from correlation analysis data.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Ai

  @type_labels %{
    budget_increase: "Budget Increase",
    budget_decrease: "Budget Decrease",
    optimization: "Optimization",
    monitoring: "Monitoring",
    general: "General"
  }

  @type_badge_classes %{
    budget_increase: "badge-primary",
    budget_decrease: "badge-warning",
    optimization: "badge-success",
    monitoring: "badge-ghost",
    general: "badge-ghost"
  }

  @filter_buttons [
    {:all, "All"},
    {:budget_increase, "Budget Increase"},
    {:budget_decrease, "Budget Decrease"},
    {:optimization, "Optimization"},
    {:monitoring, "Monitoring"},
    {:general, "General"}
  ]

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    assigns = assign(assigns, :filtered_insights, filter_insights(assigns.insights, assigns.active_type_filter))

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]}>
      <div class="max-w-4xl mx-auto mf-content px-4 py-8">
        <%!-- Page header --%>
        <h1 class="text-2xl font-bold">AI Insights</h1>
        <p class="text-base-content/60 mt-1">
          Actionable recommendations generated from your correlation analysis
        </p>

        <%!-- Type filter bar --%>
        <div data-role="type-filter" class="flex items-center gap-2 mt-6 mb-6 flex-wrap">
          <button
            :for={{type_key, label} <- @filter_buttons}
            phx-click="filter_type"
            phx-value-type={Atom.to_string(type_key)}
            class={filter_button_class(@active_type_filter, type_key)}
          >
            {label}
          </button>
        </div>

        <%!-- Empty state: no insights at all --%>
        <div
          :if={@insights == [] and @filtered_insights == []}
          data-role="no-insights-state"
          class="mf-card p-8 text-center"
        >
          <h2 class="text-xl font-semibold">No Insights Yet</h2>
          <p class="text-base-content/60 mt-2 max-w-prose mx-auto">
            AI insights are generated automatically after a correlation analysis completes.
            Run a correlation to get your first recommendations.
          </p>
          <.link navigate={~p"/correlations"} class="btn btn-primary mt-6">
            Run Correlations
          </.link>
        </div>

        <%!-- Empty filter state: insights exist but filter matches nothing --%>
        <div
          :if={@insights != [] and @filtered_insights == []}
          data-role="no-filter-results-state"
          class="mf-card p-6 text-center"
        >
          <p class="text-base-content/60">No insights match the selected filter.</p>
          <button
            phx-click="filter_type"
            phx-value-type="all"
            data-role="clear-filter"
            class="btn btn-ghost btn-sm mt-3"
          >
            Show All
          </button>
        </div>

        <%!-- Insights list --%>
        <div :if={@filtered_insights != []} data-role="insights-list" class="space-y-4">
          <div
            :for={insight <- @filtered_insights}
            data-role="insight-card"
            data-insight-id={insight.id}
            class="mf-card p-5"
          >
            <div class="flex flex-col gap-3">
              <%!-- Top row: summary + badges --%>
              <div class="flex flex-col sm:flex-row items-start justify-between gap-4">
                <p data-role="insight-summary" class="font-medium text-base-content">
                  {insight.summary}
                </p>
                <div class="flex items-center gap-2 flex-shrink-0">
                  <span
                    data-role="insight-type-badge"
                    class={["badge badge-sm", type_badge_class(insight.suggestion_type)]}
                  >
                    {type_label(insight.suggestion_type)}
                  </span>
                  <span
                    data-role="insight-confidence-badge"
                    data-confidence={insight.confidence}
                    class={["badge badge-sm", confidence_badge_class(insight.confidence)]}
                  >
                    {format_confidence(insight.confidence)} confidence
                  </span>
                </div>
              </div>

              <%!-- Full content --%>
              <div data-role="insight-content" class="text-sm text-base-content/80 leading-relaxed">
                {insight.content}
              </div>

              <%!-- Correlation reference --%>
              <div
                :if={insight.correlation_result_id}
                data-role="insight-correlation-ref"
                class="text-xs text-base-content/50"
              >
                Based on correlation result #{insight.correlation_result_id}
              </div>

              <%!-- Generated at --%>
              <div data-role="insight-generated-at" class="text-xs text-base-content/40">
                Generated {format_generated_at(insight.generated_at)}
              </div>

              <%!-- Feedback section --%>
              <div
                data-role="ai-feedback-section"
                class="pt-3 border-t border-base-content/10"
              >
                <div data-role="insight-feedback">
                  {render_feedback(assigns, insight)}
                </div>
              </div>
            </div>
          </div>
        </div>

        <%!-- AI personalization note --%>
        <div
          :if={@insights != []}
          data-role="ai-personalization-note"
          class="mt-8 pt-6 border-t border-base-content/10"
        >
          <p class="text-xs text-base-content/40 text-center">
            AI suggestions learn from your feedback and improve over time.
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp render_feedback(assigns, insight) do
    has_feedback = assigns.feedback_submitted[insight.id] == true or assigns.feedback_map[insight.id] != nil

    feedback_assigns =
      assigns
      |> Map.put(:insight, insight)
      |> Map.put(:has_feedback, has_feedback)

    render_feedback_section(feedback_assigns)
  end

  defp render_feedback_section(%{has_feedback: true} = assigns) do
    ~H"""
    <div data-role="feedback-confirmation" class="flex items-center gap-2 text-sm">
      <span class="badge badge-success badge-sm">&#10003;</span>
      <span class="text-base-content/60">
        Thanks for your feedback — helps improve future suggestions.
      </span>
    </div>
    """
  end

  defp render_feedback_section(%{has_feedback: false} = assigns) do
    ~H"""
    <p data-role="feedback-helper-text" class="text-xs text-base-content/40 mb-2">
      Your feedback helps improve future suggestions.
    </p>
    <div class="flex items-center gap-2">
      <button
        phx-click="submit_feedback"
        phx-value-insight-id={@insight.id}
        phx-value-rating="helpful"
        data-role="feedback-helpful"
        class="btn btn-ghost btn-sm"
      >
        Helpful
      </button>
      <button
        phx-click="submit_feedback"
        phx-value-insight-id={@insight.id}
        phx-value-rating="not_helpful"
        data-role="feedback-not-helpful"
        class="btn btn-ghost btn-sm"
      >
        Not helpful
      </button>
    </div>
    """
  end

  # ---------------------------------------------------------------------------
  # Mount
  # ---------------------------------------------------------------------------

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    insights = Ai.list_insights(scope, [])
    feedback_map = build_feedback_map(scope, insights)

    socket =
      socket
      |> assign(:insights, insights)
      |> assign(:feedback_map, feedback_map)
      |> assign(:active_type_filter, :all)
      |> assign(:feedback_submitted, %{})
      |> assign(:filter_buttons, @filter_buttons)
      |> assign(:page_title, "AI Insights")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("filter_type", %{"type" => "all"}, socket) do
    {:noreply, assign(socket, :active_type_filter, :all)}
  end

  def handle_event("filter_type", %{"type" => type_string}, socket) do
    type = String.to_existing_atom(type_string)
    {:noreply, assign(socket, :active_type_filter, type)}
  end

  def handle_event("submit_feedback", %{"insight-id" => id_string, "rating" => rating_string}, socket) do
    scope = socket.assigns.current_scope
    insight_id = String.to_integer(id_string)
    rating = String.to_existing_atom(rating_string)

    case Ai.submit_feedback(scope, insight_id, %{rating: rating}) do
      {:ok, feedback} ->
        socket =
          socket
          |> update(:feedback_map, &Map.put(&1, insight_id, feedback))
          |> update(:feedback_submitted, &Map.put(&1, insight_id, true))

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Insight not found.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not save feedback. Please try again.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp build_feedback_map(scope, insights) do
    Map.new(insights, fn insight ->
      {insight.id, Ai.get_feedback_for_insight(scope, insight.id)}
    end)
  end

  defp filter_insights(insights, :all), do: insights

  defp filter_insights(insights, type) do
    Enum.filter(insights, fn insight -> insight.suggestion_type == type end)
  end

  defp filter_button_class(active_filter, type_key) do
    if active_filter == type_key do
      "btn btn-primary btn-sm"
    else
      "btn btn-ghost btn-sm"
    end
  end

  defp type_label(suggestion_type), do: Map.get(@type_labels, suggestion_type, "Unknown")

  defp type_badge_class(suggestion_type), do: Map.get(@type_badge_classes, suggestion_type, "badge-ghost")

  defp confidence_badge_class(confidence) when confidence >= 0.7, do: "badge-success"
  defp confidence_badge_class(_confidence), do: "badge-ghost"

  defp format_confidence(confidence) do
    "#{round(confidence * 100)}%"
  end

  defp format_generated_at(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y at %-I:%M %p")
  end

  defp format_generated_at(_), do: ""
end
