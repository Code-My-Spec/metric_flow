defmodule MetricFlowWeb.ReportLive.Index do
  @moduledoc """
  Lists saved reports for the authenticated user and provides a new-report flow.

  Displays user-created and system-generated reports including review metric
  summaries, rolling averages, and cross-platform performance snapshots.
  Reports aggregate data from the Metrics context into presentable, shareable
  formats distinct from real-time dashboards.

  Surfaces saved visualizations as report snapshots and provides navigation to
  the AI report generator for creating new reports.

  Routes:
  - GET /reports        — list all reports for the active account (:index action)
  - GET /reports/new    — create a new report from template or blank canvas (:new action)

  Unauthenticated requests are redirected to `/users/log-in` by the router's
  `:require_authenticated_user` pipeline.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Dashboards
  alias MetricFlow.Metrics

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(%{live_action: :new} = assigns) do
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
        <div class="flex items-center gap-3 mb-2">
          <.link navigate={~p"/app/reports"} class="btn btn-ghost btn-sm">
            &larr; Back
          </.link>
        </div>
        <h1 class="text-2xl font-bold mb-2">New Report</h1>
        <p class="text-base-content/60 mb-8">
          Choose how you want to create your report.
        </p>

        <%!-- Creation options --%>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <%!-- AI generator option --%>
          <div class="mf-card p-6" data-role="report-option-ai">
            <h2 class="font-semibold text-lg mb-2">Generate with AI</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Describe what you want to see and AI will build the chart for you.
            </p>
            <.link
              navigate={~p"/app/reports/generate"}
              class="btn btn-primary btn-sm w-full sm:w-auto"
            >
              Generate with AI
            </.link>
          </div>

          <%!-- Manual visualization option --%>
          <div class="mf-card p-6" data-role="report-option-manual">
            <h2 class="font-semibold text-lg mb-2">Build Manually</h2>
            <p class="text-sm text-base-content/60 mb-4">
              Create a chart by selecting metrics and a visualization type.
            </p>
            <.link
              navigate={~p"/app/visualizations/new"}
              class="btn btn-secondary btn-sm w-full sm:w-auto"
            >
              Build Manually
            </.link>
          </div>
        </div>

        <%!-- Cancel link --%>
        <div class="mt-8">
          <.link navigate={~p"/app/reports"} class="link text-sm text-base-content/60">
            Cancel — back to Reports
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

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
        <div class="flex items-start justify-between flex-wrap gap-3 mb-8">
          <div>
            <h1 class="text-2xl font-bold">Reports</h1>
            <p class="mt-1 text-base-content/60">
              Saved metric summaries, rolling averages, and cross-platform snapshots
            </p>
          </div>
          <.link
            navigate={~p"/app/reports/new"}
            class="btn btn-primary btn-sm"
            data-role="new-report-btn"
          >
            New Report
          </.link>
        </div>

        <%!-- Metric summary strip --%>
        <div :if={@metric_names != []} data-role="metric-summary" class="mb-8">
          <h2 class="text-xl font-semibold mb-1">Available Metrics</h2>
          <p class="text-base-content/60 text-sm mb-4">
            Data sources powering your reports
          </p>
          <div class="flex flex-wrap gap-2">
            <span
              :for={name <- @metric_names}
              class="badge badge-outline"
              data-role="metric-badge"
            >
              {name}
            </span>
          </div>
        </div>

        <%!-- Saved reports (visualizations) --%>
        <div data-role="reports-list">
          <div class="flex items-center justify-between flex-wrap gap-3 mb-1">
            <h2 class="text-xl font-semibold">Saved Reports</h2>
            <input
              type="text"
              name="search"
              value={@search}
              phx-change="search"
              phx-debounce="200"
              data-role="report-search-input"
              placeholder="Search reports by name"
              class="input input-bordered input-sm w-full sm:w-64"
            />
          </div>
          <p class="text-base-content/60 text-sm mb-4">
            AI-generated and manually created report snapshots
          </p>

          <%!-- Empty state --%>
          <div
            :if={@reports == [] and @search == ""}
            data-role="empty-reports"
            class="mf-card p-8 text-center"
          >
            <p class="text-base-content/60 mb-4">No saved reports yet</p>
            <.link navigate={~p"/app/reports/new"} class="btn btn-primary btn-sm">
              Create your first report
            </.link>
          </div>

          <%!-- No search results --%>
          <div
            :if={@reports == [] and @search != ""}
            data-role="no-search-results"
            class="mf-card p-8 text-center"
          >
            <p class="text-base-content/60">No reports match "{@search}"</p>
          </div>

          <%!-- Reports grid --%>
          <div :if={@reports != []} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div
              :for={report <- @reports}
              data-role="report-card"
              data-report-id={report.id}
              class="mf-card p-5"
            >
              <div class="flex items-start justify-between gap-2 mb-2">
                <p class="font-semibold">{report.name}</p>
                <span :if={report.shareable} class="badge badge-ghost badge-sm shrink-0">
                  Shareable
                </span>
              </div>
              <p class="text-xs text-base-content/50 mb-3">
                {format_report_type(get_in(report.vega_spec, ["chart_type"]))}
              </p>
              <div class="flex items-center gap-2 mt-3">
                <.link
                  navigate={~p"/app/visualizations/#{report.id}/edit"}
                  class="btn btn-ghost btn-sm"
                  data-role={"view-report-#{report.id}"}
                >
                  View
                </.link>
                <button
                  phx-click="duplicate"
                  phx-value-id={report.id}
                  data-role={"duplicate-report-#{report.id}"}
                  class="btn btn-ghost btn-xs"
                >
                  Duplicate
                </button>
                <button
                  :if={@can_modify}
                  phx-click="delete"
                  phx-value-id={report.id}
                  data-role={"delete-report-#{report.id}"}
                  class="btn btn-ghost btn-xs text-error"
                >
                  Delete
                </button>
              </div>

              <%!-- Inline delete confirmation --%>
              <div
                :if={@confirming_delete == report.id}
                data-role={"delete-confirm-#{report.id}"}
                class="mt-3 flex items-center gap-2"
              >
                <span class="text-sm text-base-content/60">Are you sure?</span>
                <button
                  phx-click="confirm_delete"
                  phx-value-id={report.id}
                  data-role={"confirm-delete-#{report.id}"}
                  class="btn btn-error btn-xs"
                >
                  Yes, delete
                </button>
                <button
                  phx-click="cancel_delete"
                  data-role="cancel-delete"
                  class="btn btn-ghost btn-xs"
                >
                  Cancel
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- AI report generator call-to-action --%>
        <div class="mf-card p-6 mt-8 flex items-center justify-between gap-4 flex-wrap">
          <div>
            <p class="font-semibold">Generate a New Report with AI</p>
            <p class="text-sm text-base-content/60 mt-1">
              Describe what you want to visualize and AI will build the chart for you.
            </p>
          </div>
          <.link
            navigate={~p"/app/reports/generate"}
            class="btn btn-secondary btn-sm shrink-0"
            data-role="ai-generate-btn"
          >
            Generate with AI
          </.link>
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

    current_user_role =
      if socket.assigns.active_account_id do
        Accounts.get_user_role(scope, scope.user.id, socket.assigns.active_account_id)
      end

    socket =
      socket
      |> assign(:page_title, "Reports")
      |> assign(:all_reports, Dashboards.list_visualizations(scope))
      |> assign(:search, "")
      |> assign(:metric_names, Metrics.list_metric_names(scope))
      |> assign(:confirming_delete, nil)
      |> assign(:can_modify, current_user_role in [:owner, :admin, :account_manager])
      |> assign(:reports, Dashboards.list_visualizations(scope))

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Handle params
  # ---------------------------------------------------------------------------

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search", %{"search" => query}, socket) do
    filtered = filter_reports(socket.assigns.all_reports, query)

    socket =
      socket
      |> assign(:search, query)
      |> assign(:reports, filtered)

    {:noreply, socket}
  end

  def handle_event("duplicate", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Dashboards.duplicate_visualization(scope, String.to_integer(id)) do
      {:ok, _copy} ->
        all_reports = Dashboards.list_visualizations(scope)

        socket =
          socket
          |> assign(:all_reports, all_reports)
          |> assign(:reports, filter_reports(all_reports, socket.assigns.search))
          |> put_flash(:info, "Report duplicated.")

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Could not duplicate report.")}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirming_delete, String.to_integer(id))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirming_delete, nil)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    id_int = String.to_integer(id)

    if socket.assigns.can_modify do
      case Dashboards.delete_visualization(scope, id_int) do
        {:ok, _deleted} ->
          updated_all = Enum.reject(socket.assigns.all_reports, &(&1.id == id_int))

          socket =
            socket
            |> assign(:all_reports, updated_all)
            |> assign(:reports, filter_reports(updated_all, socket.assigns.search))
            |> assign(:confirming_delete, nil)
            |> put_flash(:info, "Report deleted.")

          {:noreply, socket}

        {:error, :not_found} ->
          {:noreply,
           socket
           |> assign(:confirming_delete, nil)
           |> put_flash(:error, "Report not found.")}
      end
    else
      {:noreply,
       socket
       |> assign(:confirming_delete, nil)
       |> put_flash(:error, "You are not authorized to delete reports.")}
    end
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp format_report_type("custom"), do: "Custom Report"
  defp format_report_type(nil), do: "Report"
  defp format_report_type(type), do: type |> String.replace("_", " ") |> String.capitalize()

  defp filter_reports(reports, ""), do: reports

  defp filter_reports(reports, query) do
    downcased_query = String.downcase(query)
    Enum.filter(reports, &String.contains?(String.downcase(&1.name), downcased_query))
  end
end
