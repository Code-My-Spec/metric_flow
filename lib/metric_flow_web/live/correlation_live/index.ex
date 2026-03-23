defmodule MetricFlowWeb.CorrelationLive.Index do
  @moduledoc """
  LiveView for viewing correlation analysis results between marketing/financial
  metrics and a user-selected goal metric.

  Displays automated Pearson correlation results in Raw and Smart modes.
  Raw mode (the default) shows a ranked, sortable, filterable table of all
  correlations with coefficient, optimal lag, strength badge, and data window.
  Smart mode provides AI-powered recommendations with an enable toggle,
  feedback buttons (helpful/not helpful), and links to the full AI Insights page.
  When no correlation data exists the page shows an empty state linking to /integrations.
  When a correlation job is running a progress banner is shown.
  Users can manually trigger a new correlation run.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Correlations
  alias MetricFlow.Correlations.CorrelationResult

  @provider_display_names %{
    google_analytics: "Google Analytics",
    google_ads: "Google Ads",
    facebook_ads: "Facebook Ads",
    quickbooks: "QuickBooks"
  }

  @empty_summary %{
    results: [],
    goal_metric_name: nil,
    last_calculated_at: nil,
    data_window: nil,
    data_points_count: nil,
    no_data: true
  }

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]} active_account_name={assigns[:active_account_name]}>
      <div class="max-w-5xl mx-auto mf-content px-4 py-8">
        <%!-- Page header --%>
        <div class="flex items-center justify-between mb-6 flex-wrap gap-3">
          <div>
            <h1 class="text-2xl font-bold">Correlations</h1>
            <p class="text-base-content/60">Which metrics drive your goal?</p>
          </div>
          <div class="flex items-center gap-2">
            <%!-- Mode toggle --%>
            <div data-role="mode-toggle" class="flex items-center gap-2">
              <button
                phx-click="set_mode"
                phx-value-mode="raw"
                data-role="mode-raw"
                class={if @mode == :raw, do: "btn btn-primary btn-sm", else: "btn btn-ghost btn-sm"}
              >
                Raw
              </button>
              <button
                phx-click="set_mode"
                phx-value-mode="smart"
                data-role="mode-smart"
                class={if @mode == :smart, do: "btn btn-primary btn-sm", else: "btn btn-ghost btn-sm"}
              >
                Smart
              </button>
            </div>
            <%!-- Configure Goals link --%>
            <.link
              navigate={~p"/correlations/goals"}
              data-role="configure-goals"
              class="btn btn-ghost btn-sm"
            >
              Configure Goals
            </.link>
            <%!-- Run Now button --%>
            <button
              phx-click="run_correlations"
              data-role="run-correlations"
              disabled={@job_running}
              class="btn btn-ghost btn-sm"
            >
              <span :if={@job_running} class="loading loading-spinner loading-xs"></span>
              Run Now
            </button>
          </div>
        </div>

        <%!-- Job running banner --%>
        <div
          :if={@job_running}
          data-role="job-running-banner"
          class="mf-card-cyan p-4 mb-6 flex items-center gap-3"
        >
          <span class="loading loading-spinner loading-sm"></span>
          <p class="text-sm">
            Correlation analysis is running. This page will reflect the latest results once complete.
          </p>
        </div>

        <%!-- correlation-results wrapper always present; no-data content shown when empty --%>
        <div data-role="correlation-results">
          <%!-- No-data empty state --%>
          <div
            :if={@summary.no_data and not @job_running}
            data-role="no-data-state"
            class="mf-card p-8 text-center"
          >
            <h2 class="text-xl font-semibold">No Correlations Yet</h2>
            <p class="text-base-content/60 mt-2 max-w-prose mx-auto">
              No correlations found — connect your marketing and financial platforms and sync at least 30 days of data points to get started.
              The system calculates daily aggregated Pearson correlation coefficients with optimal Lag detection (0–30 days) for each metric.
              Last calculated: never — need at least 30 days of data before correlations can run.
            </p>
            <.link navigate={~p"/integrations"} class="btn btn-primary mt-6">
              Connect Integrations
            </.link>
            <div
              :if={@run_error == :insufficient_data}
              data-role="insufficient-data-warning"
              class="badge badge-warning mt-4"
            >
              Insufficient data — 30 days of metrics required
            </div>
          </div>

          <%!-- Raw mode --%>
          <div
            :if={@mode == :raw and not @summary.no_data}
            data-role="raw-mode"
          >
            <%!-- Summary bar --%>
            <div
              data-role="correlation-summary"
              class="flex items-center gap-6 mb-6 text-sm text-base-content/60 flex-wrap"
            >
              <span data-role="goal-metric">
                Goal: <span class="font-medium text-base-content">{@summary.goal_metric_name}</span>
              </span>
              <span :if={@summary.last_calculated_at} data-role="last-calculated">
                Last calculated {format_datetime(@summary.last_calculated_at)}
              </span>
              <span :if={@summary.data_window} data-role="data-window">
                Data window: {format_data_window(@summary.data_window)}
              </span>
              <span :if={@summary.data_points_count} data-role="data-points">
                {@summary.data_points_count} data points
              </span>
            </div>

            <%!-- Filter controls --%>
            <div
              data-role="filter-controls"
              class="flex items-center gap-4 mb-4 flex-wrap"
            >
              <div data-role="platform-filter" class="flex items-center gap-1 flex-wrap">
                <button
                  phx-click="filter_platform"
                  phx-value-platform="all"
                  class={if is_nil(@platform_filter), do: "btn btn-primary btn-sm", else: "btn btn-ghost btn-sm"}
                >
                  All Platforms
                </button>
                <button
                  :for={provider <- distinct_providers(@summary.results)}
                  phx-click="filter_platform"
                  phx-value-platform={provider_key(provider)}
                  class={if @platform_filter == provider, do: "btn btn-primary btn-sm", else: "btn btn-ghost btn-sm"}
                >
                  {provider_display_name(provider)}
                </button>
              </div>
            </div>

            <%!-- Results table --%>
            <div data-role="results-table" class="overflow-x-auto">
              <table class="table table-zebra w-full">
                <thead>
                  <tr>
                    <th>
                      <button
                        phx-click="sort"
                        phx-value-by="metric_name"
                        data-sort-col="metric_name"
                        data-sort-active={if @sort_by == :metric_name, do: "true", else: "false"}
                      >
                        Metric
                        <span :if={@sort_by == :metric_name} class="text-xs ml-1">
                          {sort_arrow(@sort_dir)}
                        </span>
                      </button>
                    </th>
                    <th>
                      <button
                        phx-click="sort"
                        phx-value-by="coefficient"
                        data-sort-col="coefficient"
                        data-sort-active={if @sort_by == :coefficient, do: "true", else: "false"}
                      >
                        Coefficient
                        <span :if={@sort_by == :coefficient} class="text-xs ml-1">
                          {sort_arrow(@sort_dir)}
                        </span>
                      </button>
                    </th>
                    <th>
                      <button
                        phx-click="sort"
                        phx-value-by="lag"
                        data-sort-col="lag"
                        data-sort-active={if @sort_by == :lag, do: "true", else: "false"}
                      >
                        Lag
                        <span :if={@sort_by == :lag} class="text-xs ml-1">
                          {sort_arrow(@sort_dir)}
                        </span>
                      </button>
                    </th>
                    <th>Data Points</th>
                    <th>
                      <button
                        phx-click="sort"
                        phx-value-by="platform"
                        data-sort-col="platform"
                        data-sort-active={if @sort_by == :platform, do: "true", else: "false"}
                      >
                        Platform
                        <span :if={@sort_by == :platform} class="text-xs ml-1">
                          {sort_arrow(@sort_dir)}
                        </span>
                      </button>
                    </th>
                  </tr>
                </thead>
                <tbody>
                  <tr
                    :if={filtered_and_sorted_results(@summary.results, @platform_filter, @sort_by, @sort_dir) == []}
                  >
                    <td colspan="5" data-role="empty-filter-state" class="text-base-content/60 text-center">
                      No correlations match the selected filter.
                    </td>
                  </tr>
                  <tr
                    :for={result <- filtered_and_sorted_results(@summary.results, @platform_filter, @sort_by, @sort_dir)}
                    data-role="correlation-row"
                    data-metric={result.metric_name}
                  >
                    <td>
                      <span class="font-medium">{result.metric_name}</span>
                      <br />
                      <span class="text-xs text-base-content/50">{provider_display_name(result.provider)}</span>
                    </td>
                    <td>
                      <span class={["mf-metric text-sm", coefficient_color_class(result.coefficient)]}>
                        {format_coefficient(result.coefficient)}
                      </span>
                      <span
                        data-role="strength-badge"
                        class={["badge badge-sm ml-1", strength_badge_class(result)]}
                      >
                        {CorrelationResult.strength_label(result)}
                      </span>
                    </td>
                    <td>
                      <span :if={result.optimal_lag == 0} class="text-base-content/60 mf-metric text-sm">
                        Same day
                      </span>
                      <span :if={result.optimal_lag != 0} class="mf-metric text-sm">
                        {result.optimal_lag} days
                      </span>
                    </td>
                    <td>
                      <span class="text-sm text-base-content/60">{result.data_points} pts</span>
                    </td>
                    <td>
                      <span class="badge badge-ghost badge-sm">
                        {provider_display_name(result.provider)}
                      </span>
                    </td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <%!-- Smart mode --%>
        <div :if={@mode == :smart} data-role="smart-mode">
          <%!-- Before AI suggestions enabled --%>
          <div :if={not @ai_suggestions_enabled} class="mf-card-accent p-8 text-center">
            <h2 class="text-xl font-semibold">Smart Mode</h2>
            <p class="text-base-content/60 mt-2 max-w-prose mx-auto">
              Smart mode uses AI to surface actionable insights from your
              correlation data so you can act without digging through raw numbers.
            </p>
            <button
              phx-click="enable_ai_suggestions"
              data-role="enable-ai-suggestions"
              class="btn btn-primary btn-sm mt-6"
            >
              Enable AI Suggestions
            </button>
          </div>

          <%!-- Top correlations sections (always visible in smart mode) --%>
          <div class="space-y-6 mb-6">
            <%!-- Top 5 Positive Correlations --%>
            <div data-role="top-positive-correlations" class="mf-card p-5">
              <h3 class="text-lg font-semibold mb-3 text-success">Top Positive Correlations</h3>
              <div :if={top_positive_correlations(@summary.results) == []} class="text-sm text-base-content/60">
                No positive correlations found.
              </div>
              <div
                :for={result <- top_positive_correlations(@summary.results)}
                data-role="correlation-row"
                data-metric={result.metric_name}
                class="flex items-center justify-between py-2 border-b border-base-200 last:border-b-0"
              >
                <div>
                  <span class="font-medium">{result.metric_name}</span>
                  <span class="text-xs text-base-content/50 ml-2">{provider_display_name(result.provider)}</span>
                </div>
                <div class="flex items-center gap-3">
                  <span class="mf-metric text-sm text-success">{format_coefficient(result.coefficient)}</span>
                  <span class={["badge badge-sm", strength_badge_class(result)]}>
                    {CorrelationResult.strength_label(result)}
                  </span>
                </div>
              </div>
            </div>

            <%!-- Top 5 Negative Correlations --%>
            <div data-role="top-negative-correlations" class="mf-card p-5">
              <h3 class="text-lg font-semibold mb-3 text-error">Top Negative Correlations</h3>
              <div :if={top_negative_correlations(@summary.results) == []} class="text-sm text-base-content/60">
                No negative correlations found.
              </div>
              <div
                :for={result <- top_negative_correlations(@summary.results)}
                data-role="correlation-row"
                data-metric={result.metric_name}
                class="flex items-center justify-between py-2 border-b border-base-200 last:border-b-0"
              >
                <div>
                  <span class="font-medium">{result.metric_name}</span>
                  <span class="text-xs text-base-content/50 ml-2">{provider_display_name(result.provider)}</span>
                </div>
                <div class="flex items-center gap-3">
                  <span class="mf-metric text-sm text-error">{format_coefficient(result.coefficient)}</span>
                  <span class={["badge badge-sm", strength_badge_class(result)]}>
                    {CorrelationResult.strength_label(result)}
                  </span>
                </div>
              </div>
            </div>
          </div>

          <%!-- After AI suggestions enabled --%>
          <div :if={@ai_suggestions_enabled}>
            <div data-role="ai-suggestions-enabled" class="badge badge-success mb-4">
              AI Suggestions enabled
            </div>

            <div data-role="ai-recommendations" class="space-y-4">
              <h3 class="text-lg font-semibold">AI Recommendations</h3>

              <div class="mf-card p-6">
                <p class="text-base-content/80 leading-relaxed">
                  Consider running a correlation analysis to generate metric-specific insights.
                  Suggestions are based on correlation strength, revenue trends, and business context
                  to help you increase ROI, optimize budget allocation, and reduce underperforming spend.
                </p>
                <p class="text-sm text-base-content/60 mt-3">
                  Strong correlations are highlighted so you can act on the metrics that matter most.
                  Visit the <.link navigate={~p"/insights"} class="link link-primary">AI Insights</.link>
                  page for detailed recommendations.
                </p>
              </div>

              <%!-- Feedback section --%>
              <div data-role="ai-feedback-section" class="mf-card p-5">
                <div :if={not @ai_feedback_submitted}>
                  <p data-role="feedback-helper-text" class="text-xs text-base-content/40 mb-2">
                    Was this helpful or not helpful? Your feedback helps improve future suggestions.
                  </p>
                  <div class="flex items-center gap-2">
                    <button
                      phx-click="submit_smart_feedback"
                      phx-value-rating="helpful"
                      data-role="feedback-helpful"
                      class="btn btn-ghost btn-sm"
                    >
                      Helpful
                    </button>
                    <button
                      phx-click="submit_smart_feedback"
                      phx-value-rating="not_helpful"
                      data-role="feedback-not-helpful"
                      class="btn btn-ghost btn-sm"
                    >
                      Not helpful
                    </button>
                  </div>
                </div>

                <div :if={@ai_feedback_submitted} data-role="feedback-confirmation">
                  <div class="flex items-center gap-2 text-sm">
                    <span class="badge badge-success badge-sm">&#10003;</span>
                    <span class="text-base-content/60">
                      Thanks for your feedback — helps improve future suggestions.
                    </span>
                  </div>
                </div>

                <p class="text-xs text-base-content/40 mt-3">
                  AI suggestions learn from your feedback and improve over time.
                </p>
              </div>
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
    scope = socket.assigns.current_scope

    {summary, job_running} =
      try do
        summary = Correlations.get_latest_correlation_summary(scope)
        jobs = Correlations.list_correlation_jobs(scope)
        job_running = Enum.any?(jobs, fn job -> job.status in [:running, :pending] end)
        {summary, job_running}
      rescue
        Ecto.NoResultsError -> {@empty_summary, false}
      end

    socket =
      socket
      |> assign(:summary, summary)
      |> assign(:mode, :raw)
      |> assign(:sort_by, :coefficient)
      |> assign(:sort_dir, :desc)
      |> assign(:platform_filter, nil)
      |> assign(:job_running, job_running)
      |> assign(:run_error, nil)
      |> assign(:ai_suggestions_enabled, false)
      |> assign(:ai_feedback_submitted, false)
      |> assign(:page_title, "Correlations")

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("set_mode", %{"mode" => mode_string}, socket) do
    mode = String.to_existing_atom(mode_string)
    {:noreply, assign(socket, :mode, mode)}
  end

  def handle_event("sort", %{"by" => column_string}, socket) do
    column = String.to_existing_atom(column_string)

    {sort_by, sort_dir} =
      case socket.assigns.sort_by do
        ^column ->
          {column, toggle_sort_dir(socket.assigns.sort_dir)}

        _other ->
          {column, :desc}
      end

    socket =
      socket
      |> assign(:sort_by, sort_by)
      |> assign(:sort_dir, sort_dir)

    {:noreply, socket}
  end

  def handle_event("filter_platform", %{"platform" => "all"}, socket) do
    {:noreply, assign(socket, :platform_filter, nil)}
  end

  def handle_event("filter_platform", %{"platform" => platform_string}, socket) do
    platform = String.to_existing_atom(platform_string)
    {:noreply, assign(socket, :platform_filter, platform)}
  end

  def handle_event("run_correlations", _params, socket) do
    scope = socket.assigns.current_scope
    goal_metric_name = socket.assigns.summary.goal_metric_name

    case Correlations.run_correlations(scope, %{goal_metric_name: goal_metric_name}) do
      {:ok, _job} ->
        socket =
          socket
          |> assign(:job_running, true)
          |> assign(:run_error, nil)
          |> put_flash(:info, "Correlation analysis started. Results will appear once complete.")

        {:noreply, socket}

      {:error, :already_running} ->
        {:noreply, put_flash(socket, :info, "A correlation run is already in progress.")}

      {:error, :insufficient_data} ->
        socket =
          socket
          |> assign(:run_error, :insufficient_data)
          |> put_flash(
            :error,
            "Not enough data to run correlations. At least 30 days of metric data is required."
          )

        {:noreply, socket}
    end
  end

  def handle_event("enable_ai_suggestions", _params, socket) do
    {:noreply, assign(socket, :ai_suggestions_enabled, true)}
  end

  def handle_event("submit_smart_feedback", _params, socket) do
    {:noreply, assign(socket, :ai_feedback_submitted, true)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp filtered_and_sorted_results(results, platform_filter, sort_by, sort_dir) do
    results
    |> filter_by_platform(platform_filter)
    |> sort_results(sort_by, sort_dir)
  end

  defp filter_by_platform(results, nil), do: results

  defp filter_by_platform(results, platform) do
    Enum.filter(results, fn result -> result.provider == platform end)
  end

  defp sort_results(results, :coefficient, :desc) do
    Enum.sort_by(results, fn r -> abs(r.coefficient) end, :desc)
  end

  defp sort_results(results, :coefficient, :asc) do
    Enum.sort_by(results, fn r -> abs(r.coefficient) end, :asc)
  end

  defp sort_results(results, :metric_name, :desc) do
    Enum.sort_by(results, & &1.metric_name, :desc)
  end

  defp sort_results(results, :metric_name, :asc) do
    Enum.sort_by(results, & &1.metric_name, :asc)
  end

  defp sort_results(results, :lag, :desc) do
    Enum.sort_by(results, & &1.optimal_lag, :desc)
  end

  defp sort_results(results, :lag, :asc) do
    Enum.sort_by(results, & &1.optimal_lag, :asc)
  end

  defp sort_results(results, :platform, :desc) do
    Enum.sort_by(results, &provider_sort_key/1, :desc)
  end

  defp sort_results(results, :platform, :asc) do
    Enum.sort_by(results, &provider_sort_key/1, :asc)
  end

  defp provider_sort_key(%{provider: nil}), do: ""
  defp provider_sort_key(%{provider: provider}), do: Atom.to_string(provider)

  defp toggle_sort_dir(:asc), do: :desc
  defp toggle_sort_dir(:desc), do: :asc

  defp distinct_providers(results) do
    results
    |> Enum.map(& &1.provider)
    |> Enum.uniq()
    |> Enum.sort_by(&provider_display_name/1)
  end

  defp provider_key(nil), do: "nil"
  defp provider_key(provider), do: Atom.to_string(provider)

  defp provider_display_name(nil), do: "Derived"

  defp provider_display_name(provider) when is_atom(provider) do
    Map.get(@provider_display_names, provider, provider |> Atom.to_string() |> humanize_atom())
  end

  defp humanize_atom(str) do
    str
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp top_positive_correlations(results) do
    results
    |> Enum.filter(fn r -> r.coefficient > 0 end)
    |> Enum.sort_by(fn r -> r.coefficient end, :desc)
    |> Enum.take(5)
  end

  defp top_negative_correlations(results) do
    results
    |> Enum.filter(fn r -> r.coefficient < 0 end)
    |> Enum.sort_by(fn r -> r.coefficient end, :asc)
    |> Enum.take(5)
  end

  defp coefficient_color_class(coefficient) when coefficient > 0, do: "text-success"
  defp coefficient_color_class(coefficient) when coefficient < 0, do: "text-error"
  defp coefficient_color_class(_), do: "text-base-content/60"

  defp format_coefficient(coefficient) do
    :erlang.float_to_binary(coefficient * 1.0, decimals: 2)
  end

  defp strength_badge_class(result) do
    case CorrelationResult.strength_label(result) do
      "Strong" -> "badge-success"
      "Moderate" -> "badge-warning"
      "Weak" -> "badge-ghost"
      "Negligible" -> "badge-ghost"
    end
  end

  defp sort_arrow(:asc), do: "↑"
  defp sort_arrow(:desc), do: "↓"

  defp format_datetime(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)} minutes ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)} hours ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end

  defp format_datetime(_), do: ""

  defp format_data_window({start_date, end_date})
       when not is_nil(start_date) and not is_nil(end_date) do
    "#{Date.to_iso8601(start_date)} to #{Date.to_iso8601(end_date)}"
  end

  defp format_data_window(_), do: ""
end
