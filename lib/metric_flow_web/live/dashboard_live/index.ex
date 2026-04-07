defmodule MetricFlowWeb.DashboardLive.Index do
  @moduledoc """
  Lists dashboards available to the authenticated user.

  Shows both the user's own saved dashboards and system-provided canned
  dashboards. Supports inline delete confirmation for user-owned dashboards.
  Unauthenticated requests are redirected to `/users/log-in` by the router's
  `:require_authenticated_user` pipeline.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Dashboards

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} white_label_config={assigns[:white_label_config]} active_account_name={assigns[:active_account_name]}>
      <div class="max-w-5xl mx-auto mf-content px-4 py-8">
        <%!-- Page header --%>
        <div class="flex items-start justify-between flex-wrap gap-3 mb-8">
          <div>
            <h1 class="text-2xl font-bold">Dashboards</h1>
            <p class="mt-1 text-base-content/60">Your saved views and system dashboards</p>
          </div>
          <.link navigate={~p"/app/dashboards/new"} class="btn btn-primary btn-sm" data-role="new-dashboard-btn">
            New Dashboard
          </.link>
        </div>

        <%!-- Canned dashboards section --%>
        <div :if={@canned_dashboards != []} data-role="canned-dashboards" class="mb-8">
          <h2 class="text-xl font-semibold mb-1">System Dashboards</h2>
          <p class="text-base-content/60 text-sm mb-4">Pre-built views ready to use</p>
          <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div
              :for={dashboard <- @canned_dashboards}
              data-role="dashboard-card"
              data-dashboard-id={dashboard.id}
              data-built-in="true"
              class="mf-card p-5"
            >
              <div class="flex items-start justify-between gap-2 mb-2">
                <p class="font-semibold">{dashboard.name}</p>
                <span class="badge badge-ghost badge-sm shrink-0">Built-in</span>
              </div>
              <p :if={dashboard.description} class="text-sm text-base-content/60 mb-3">
                {dashboard.description}
              </p>
              <div class="flex gap-2 mt-3">
                <.link navigate={~p"/app/dashboards/#{dashboard.id}"} class="btn btn-ghost btn-sm" data-role={"view-dashboard-#{dashboard.id}"}>
                  View
                </.link>
              </div>
            </div>
          </div>
        </div>

        <%!-- User dashboards section --%>
        <div data-role="user-dashboards">
          <h2 class="text-xl font-semibold mb-1">My Dashboards</h2>
          <p class="text-base-content/60 text-sm mb-4">Dashboards you've created</p>

          <%!-- Empty state --%>
          <div :if={@user_dashboards == []} data-role="empty-user-dashboards" class="mf-card p-8 text-center">
            <p class="text-base-content/60 mb-4">No dashboards yet</p>
            <.link navigate={~p"/app/dashboards/new"} class="btn btn-primary btn-sm">
              Create your first dashboard
            </.link>
          </div>

          <%!-- Dashboard grid --%>
          <div :if={@user_dashboards != []} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div
              :for={dashboard <- @user_dashboards}
              data-role="dashboard-card"
              data-dashboard-id={dashboard.id}
              data-built-in="false"
              class="mf-card p-5"
            >
              <p class="font-semibold mb-1">{dashboard.name}</p>
              <p :if={dashboard.description} class="text-sm text-base-content/60 mb-3">
                {dashboard.description}
              </p>
              <div class="flex items-center gap-2 mt-3">
                <.link navigate={~p"/app/dashboards/#{dashboard.id}"} class="btn btn-ghost btn-sm" data-role={"view-dashboard-#{dashboard.id}"}>
                  View
                </.link>
                <.link navigate={~p"/app/dashboards/#{dashboard.id}/edit"} class="btn btn-ghost btn-sm" data-role={"edit-dashboard-#{dashboard.id}"}>
                  Edit
                </.link>
                <button
                  phx-click="delete"
                  phx-value-id={dashboard.id}
                  data-role={"delete-dashboard-#{dashboard.id}"}
                  class="btn btn-ghost btn-xs text-error"
                >
                  Delete
                </button>
              </div>

              <%!-- Inline delete confirmation --%>
              <div
                :if={@confirming_delete == dashboard.id}
                data-role={"delete-confirm-#{dashboard.id}"}
                class="mt-3 flex items-center gap-2"
              >
                <span class="text-sm text-base-content/60">Are you sure?</span>
                <button
                  phx-click="confirm_delete"
                  phx-value-id={dashboard.id}
                  data-role={"confirm-delete-#{dashboard.id}"}
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

    socket =
      socket
      |> assign(:page_title, "Dashboards")
      |> assign(:user_dashboards, Dashboards.list_dashboards(scope))
      |> assign(:canned_dashboards, Dashboards.list_canned_dashboards())
      |> assign(:confirming_delete, nil)

    {:ok, socket}
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirming_delete, String.to_integer(id))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirming_delete, nil)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Dashboards.delete_dashboard(scope, String.to_integer(id)) do
      {:ok, _deleted} ->
        updated_dashboards =
          Enum.reject(socket.assigns.user_dashboards, &(&1.id == String.to_integer(id)))

        socket =
          socket
          |> assign(:user_dashboards, updated_dashboards)
          |> assign(:confirming_delete, nil)
          |> put_flash(:info, "Dashboard deleted.")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Dashboard not found.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You can't delete that dashboard.")}
    end
  end
end
