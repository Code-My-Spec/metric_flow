defmodule MetricFlowWeb.DashboardLive.Index do
  @moduledoc """
  Lists dashboards available to the authenticated user.

  Shows both the user's own saved dashboards and system-provided canned
  dashboards. Supports inline delete confirmation for user-owned dashboards.
  Unauthenticated requests are redirected to `/users/log-in` by the router's
  `:require_authenticated_user` pipeline.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts.Authorization
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
        <div class="flex items-start justify-between flex-wrap gap-3 mb-8">
          <div>
            <h1 class="text-2xl font-bold">Dashboards</h1>
            <p class="mt-1 text-base-content/60">Your saved views and system dashboards</p>
          </div>
          <.link
            navigate={~p"/app/dashboards/new"}
            class="btn btn-primary btn-sm"
            data-role="new-dashboard-btn"
          >
            New Dashboard
          </.link>
        </div>

        <%!-- Canned dashboards section -- hidden while actively searching
           Dana's own dashboards (Story 75, criterion 1073: a search shows
           only matching dashboards of hers, not unrelated templates). --%>
        <div
          :if={@canned_dashboards != [] && @search_query == ""}
          data-role="canned-dashboards"
          class="mb-8"
        >
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
                <.link
                  navigate={~p"/app/dashboards/#{dashboard.id}"}
                  class="btn btn-ghost btn-sm"
                  data-role={"view-dashboard-#{dashboard.id}"}
                >
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

          <%!-- Search --%>
          <div :if={@user_dashboards != []} data-role="dashboard-search" class="mb-4">
            <form phx-change="search">
              <input
                type="text"
                name="query"
                value={@search_query}
                placeholder="Search dashboards by name"
                class="input input-bordered input-sm w-full max-w-xs"
              />
            </form>
          </div>

          <%!-- Empty state --%>
          <div
            :if={@user_dashboards == []}
            data-role="empty-user-dashboards"
            class="mf-card p-8 text-center"
          >
            <p class="text-base-content/60 mb-4">No dashboards yet</p>
            <.link navigate={~p"/app/dashboards/new"} class="btn btn-primary btn-sm">
              Create your first dashboard
            </.link>
          </div>

          <%!-- No results for the current search --%>
          <div
            :if={@user_dashboards != [] && @filtered_dashboards == []}
            data-role="empty-search-results"
            class="mf-card p-8 text-center"
          >
            <p class="text-base-content/60">No dashboards match your search</p>
          </div>

          <%!-- Dashboard grid --%>
          <div :if={@filtered_dashboards != []} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
            <div
              :for={dashboard <- @filtered_dashboards}
              data-role="dashboard-card"
              data-dashboard-id={dashboard.id}
              data-built-in="false"
              class="mf-card p-5"
            >
              <div :if={@renaming_id == dashboard.id} data-role={"rename-form-#{dashboard.id}"}>
                <form phx-submit="rename">
                  <input type="hidden" name="dashboard_id" value={dashboard.id} />
                  <input
                    type="text"
                    name="name"
                    value={dashboard.name}
                    data-role={"rename-input-#{dashboard.id}"}
                    class="input input-bordered input-sm w-full mb-1"
                  />
                  <div class="flex gap-2">
                    <button
                      type="submit"
                      data-role={"confirm-rename-#{dashboard.id}"}
                      class="btn btn-primary btn-xs"
                    >
                      Save
                    </button>
                    <button
                      type="button"
                      phx-click="cancel_rename"
                      data-role="cancel-rename"
                      class="btn btn-ghost btn-xs"
                    >
                      Cancel
                    </button>
                  </div>
                </form>
              </div>
              <p :if={@renaming_id != dashboard.id} class="font-semibold mb-1">{dashboard.name}</p>
              <p :if={dashboard.description} class="text-sm text-base-content/60 mb-3">
                {dashboard.description}
              </p>
              <div class="flex items-center gap-2 mt-3">
                <.link
                  navigate={~p"/app/dashboards/#{dashboard.id}"}
                  class="btn btn-ghost btn-sm"
                  data-role={"view-dashboard-#{dashboard.id}"}
                >
                  View
                </.link>
                <.link
                  navigate={~p"/app/dashboards/#{dashboard.id}/edit"}
                  class="btn btn-ghost btn-sm"
                  data-role={"edit-dashboard-#{dashboard.id}"}
                >
                  Edit with agent
                </.link>
                <button
                  phx-click="start_rename"
                  phx-value-id={dashboard.id}
                  data-role={"rename-dashboard-#{dashboard.id}"}
                  class="btn btn-ghost btn-sm"
                >
                  Rename
                </button>
                <button
                  phx-click="toggle_favorite"
                  phx-value-id={dashboard.id}
                  data-role={"favorite-dashboard-#{dashboard.id}"}
                  class={["btn btn-ghost btn-sm", dashboard.favorite && "text-warning"]}
                >
                  {if dashboard.favorite, do: "★ Favorited", else: "☆ Favorite"}
                </button>
                <button
                  phx-click="duplicate"
                  phx-value-id={dashboard.id}
                  data-role={"duplicate-dashboard-#{dashboard.id}"}
                  class="btn btn-ghost btn-sm"
                >
                  Duplicate
                </button>
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
      |> assign(:canned_dashboards, Dashboards.list_canned_dashboards())
      |> assign(:confirming_delete, nil)
      |> assign(:renaming_id, nil)
      |> assign(:search_query, "")
      |> assign_dashboards(Dashboards.list_dashboards(scope))

    {:ok, socket}
  end

  # Story 75, criterion 1073: keeps @user_dashboards (the full list) and
  # @filtered_dashboards (what the search box currently narrows it to) in
  # sync whenever either the list or the query changes.
  defp assign_dashboards(socket, user_dashboards) do
    socket
    |> assign(:user_dashboards, user_dashboards)
    |> assign(
      :filtered_dashboards,
      filter_dashboards(user_dashboards, socket.assigns.search_query)
    )
  end

  defp filter_dashboards(dashboards, ""), do: dashboards

  defp filter_dashboards(dashboards, query) do
    query = String.downcase(query)
    Enum.filter(dashboards, &String.contains?(String.downcase(&1.name), query))
  end

  # ---------------------------------------------------------------------------
  # Event handlers
  # ---------------------------------------------------------------------------

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket =
      socket
      |> assign(:search_query, query)
      |> assign_dashboards(socket.assigns.user_dashboards)

    {:noreply, socket}
  end

  def handle_event("toggle_favorite", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    id = String.to_integer(id)
    dashboard = Enum.find(socket.assigns.user_dashboards, &(&1.id == id))

    case dashboard &&
           Dashboards.update_dashboard(scope, dashboard, %{"favorite" => !dashboard.favorite}) do
      {:ok, _updated} ->
        {:noreply, assign_dashboards(socket, Dashboards.list_dashboards(scope))}

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :confirming_delete, String.to_integer(id))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :confirming_delete, nil)}
  end

  def handle_event("confirm_delete", %{"id" => id}, socket) do
    if can_build?(socket) do
      scope = socket.assigns.current_scope

      case Dashboards.delete_dashboard(scope, String.to_integer(id)) do
        {:ok, _deleted} ->
          updated_dashboards =
            Enum.reject(socket.assigns.user_dashboards, &(&1.id == String.to_integer(id)))

          socket =
            socket
            |> assign_dashboards(updated_dashboards)
            |> assign(:confirming_delete, nil)
            |> put_flash(:info, "Dashboard deleted.")

          {:noreply, socket}

        {:error, :not_found} ->
          {:noreply, put_flash(socket, :error, "Dashboard not found.")}

        {:error, :unauthorized} ->
          {:noreply, put_flash(socket, :error, "You can't delete that dashboard.")}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to delete dashboards.")}
    end
  end

  # Story 75, criterion 1068: Dana can rename a dashboard from the list
  # itself, not only from inside the builder.
  def handle_event("start_rename", %{"id" => id}, socket) do
    {:noreply, assign(socket, :renaming_id, String.to_integer(id))}
  end

  def handle_event("cancel_rename", _params, socket) do
    {:noreply, assign(socket, :renaming_id, nil)}
  end

  def handle_event("duplicate", %{"id" => id}, socket) do
    if can_build?(socket) do
      scope = socket.assigns.current_scope
      id = String.to_integer(id)
      dashboard = Enum.find(socket.assigns.user_dashboards, &(&1.id == id))

      case dashboard && Dashboards.duplicate_dashboard(scope, dashboard) do
        {:ok, _new_dashboard} ->
          socket =
            socket
            |> assign_dashboards(Dashboards.list_dashboards(scope))
            |> put_flash(:info, "Dashboard duplicated.")

          {:noreply, socket}

        _ ->
          {:noreply, socket}
      end
    else
      {:noreply, put_flash(socket, :error, "You don't have permission to duplicate dashboards.")}
    end
  end

  def handle_event("rename", %{"dashboard_id" => id, "name" => name}, socket) do
    if can_build?(socket) do
      scope = socket.assigns.current_scope
      id = String.to_integer(id)
      dashboard = Enum.find(socket.assigns.user_dashboards, &(&1.id == id))

      case dashboard && Dashboards.update_dashboard(scope, dashboard, %{"name" => name}) do
        {:ok, updated} ->
          socket =
            socket
            |> assign_dashboards(replace_dashboard(socket.assigns.user_dashboards, updated))
            |> assign(:renaming_id, nil)

          {:noreply, socket}

        _ ->
          {:noreply, assign(socket, :renaming_id, nil)}
      end
    else
      {:noreply,
       socket
       |> assign(:renaming_id, nil)
       |> put_flash(:error, "You don't have permission to edit dashboards.")}
    end
  end

  defp replace_dashboard(dashboards, updated) do
    Enum.map(dashboards, fn d -> if d.id == updated.id, do: updated, else: d end)
  end

  # Story 40, criteria 601/602: saving, editing and deleting a dashboard
  # from the list requires build access, same as the editor's own mount
  # gate -- a read-only agency member is refused here too, not only when
  # opening the editor directly.
  defp can_build?(socket) do
    case socket.assigns[:active_account_id] do
      nil ->
        true

      account_id ->
        Authorization.can?(socket.assigns.current_scope, :build, %{account_id: account_id})
    end
  end
end
