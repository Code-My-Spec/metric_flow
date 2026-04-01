defmodule MetricFlowWeb.VisualizationLive.Index do
  @moduledoc """
  Lists saved visualizations for the authenticated user.

  Shows all standalone visualizations the user has created. Supports inline
  delete confirmation for each visualization. Unauthenticated requests are
  redirected to `/users/log-in` by the router's `:require_authenticated_user`
  pipeline.
  """

  use MetricFlowWeb, :live_view

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
     
    >
      <div class="max-w-5xl mx-auto mf-content px-4 py-8">
        <%!-- Page header --%>
        <div class="flex items-start justify-between flex-wrap gap-3 mb-8">
          <div>
            <h1 class="text-2xl font-bold">Visualizations</h1>
            <p class="mt-1 text-base-content/60">Your saved charts and visualizations</p>
          </div>
          <.link
            navigate={~p"/visualizations/new"}
            class="btn btn-primary btn-sm"
            data-role="new-visualization-btn"
          >
            New Visualization
          </.link>
        </div>

        <%!-- Empty state --%>
        <div
          :if={@visualizations == []}
          data-role="empty-visualizations"
          class="mf-card p-8 text-center"
        >
          <p class="text-base-content/60 mb-4">No visualizations yet</p>
          <.link navigate={~p"/visualizations/new"} class="btn btn-primary btn-sm">
            Create your first visualization
          </.link>
        </div>

        <%!-- Visualization grid --%>
        <div :if={@visualizations != []} class="grid grid-cols-1 sm:grid-cols-2 gap-4">
          <div
            :for={visualization <- @visualizations}
            data-role="visualization-card"
            data-visualization-id={visualization.id}
            class="mf-card p-5"
          >
            <p class="font-semibold mb-1">{visualization.name}</p>
            <p :if={visualization.shareable} class="text-xs text-base-content/60 mb-3">
              Shareable
            </p>
            <div class="flex items-center gap-2 mt-3">
              <.link
                navigate={~p"/visualizations/#{visualization.id}/edit"}
                class="btn btn-ghost btn-sm"
                data-role={"edit-visualization-#{visualization.id}"}
              >
                Edit
              </.link>
              <button
                phx-click="delete"
                phx-value-id={visualization.id}
                data-role={"delete-visualization-#{visualization.id}"}
                class="btn btn-ghost btn-xs text-error"
              >
                Delete
              </button>
            </div>

            <%!-- Inline delete confirmation --%>
            <div
              :if={@confirming_delete == visualization.id}
              data-role={"delete-confirm-#{visualization.id}"}
              class="mt-3 flex items-center gap-2"
            >
              <span class="text-sm text-base-content/60">Are you sure?</span>
              <button
                phx-click="confirm_delete"
                phx-value-id={visualization.id}
                data-role={"confirm-delete-#{visualization.id}"}
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
      |> assign(:page_title, "Visualizations")
      |> assign(:visualizations, Dashboards.list_visualizations(scope))
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
    id_int = String.to_integer(id)

    case Dashboards.delete_visualization(scope, id_int) do
      {:ok, _deleted} ->
        updated = Enum.reject(socket.assigns.visualizations, &(&1.id == id_int))

        socket =
          socket
          |> assign(:visualizations, updated)
          |> assign(:confirming_delete, nil)
          |> put_flash(:info, "Visualization deleted.")

        {:noreply, socket}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> assign(:confirming_delete, nil)
         |> put_flash(:error, "Visualization not found.")}
    end
  end
end
