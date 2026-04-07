defmodule MetricFlowWeb.AgencyLive.Subscriptions do
  @moduledoc """
  Agency customer subscription management dashboard.

  Displays subscriptions across the agency's client accounts with
  summary stats, search, pagination, and cancel actions.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Billing
  alias MetricFlow.Billing.BillingRepository

  @per_page 20

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} active_account_name={assigns[:active_account_name]}>
      <div class="mx-auto max-w-6xl">
        <.header>
          Customer Subscriptions
          <:subtitle>Manage your agency's subscriber accounts</:subtitle>
        </.header>

        <div class="mt-8 space-y-6">
          <%!-- Summary stats --%>
          <div class="stats shadow w-full">
            <div class="stat">
              <div class="stat-title">Active Subscribers</div>
              <div class="stat-value">{@active_count}</div>
            </div>
            <div class="stat">
              <div class="stat-title">MRR</div>
              <div class="stat-value">{format_mrr(@mrr)}</div>
            </div>
            <div class="stat">
              <div class="stat-title">Past Due</div>
              <div class="stat-value text-warning">{@past_due_count}</div>
            </div>
          </div>

          <%!-- Search --%>
          <div class="form-control">
            <form phx-change="search" phx-submit="search">
              <input
                type="text"
                name="query"
                value={@search}
                placeholder="Search by customer ID or email..."
                class="input w-full"
                phx-debounce="300"
              />
            </form>
          </div>

          <%!-- Subscriptions table --%>
          <div class="card bg-base-100 shadow">
            <div class="card-body p-0">
              <div :if={@subscriptions == []} class="p-6 text-center text-base-content/60">
                No customer subscriptions yet
              </div>
              <div :if={@subscriptions != []} class="overflow-x-auto">
                <table class="table w-full">
                  <thead>
                    <tr>
                      <th>Customer</th>
                      <th>Plan</th>
                      <th>Status</th>
                      <th>Start Date</th>
                      <th>Period End</th>
                      <th>Actions</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr :for={sub <- @subscriptions} data-role="subscription-row">
                      <td class="font-mono text-xs">{sub.stripe_customer_id}</td>
                      <td>{if sub.plan, do: sub.plan.name, else: "—"}</td>
                      <td>
                        <span :if={sub.status == :active} class="badge badge-success">Active</span>
                        <span :if={sub.status == :past_due} class="badge badge-warning">Past due</span>
                        <span :if={sub.status == :cancelled} class="badge badge-ghost">Cancelled</span>
                        <span :if={sub.status == :trialing} class="badge badge-info">Trialing</span>
                      </td>
                      <td>{format_date(sub.inserted_at)}</td>
                      <td>{format_date(sub.current_period_end)}</td>
                      <td>
                        <button
                          :if={sub.status == :active}
                          phx-click="cancel_customer_subscription"
                          phx-value-id={sub.id}
                          data-confirm="Cancel this customer's subscription at period end?"
                          class="btn btn-xs btn-ghost text-error"
                        >
                          Cancel
                        </button>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <%!-- Pagination --%>
              <div :if={@subscriptions != []} class="flex justify-center gap-2 p-4">
                <button
                  :if={@page > 0}
                  phx-click="prev_page"
                  class="btn btn-sm btn-ghost"
                >
                  Previous
                </button>
                <span class="btn btn-sm btn-disabled">
                  Page {@page + 1}
                </span>
                <button
                  :if={length(@subscriptions) == @per_page}
                  phx-click="next_page"
                  class="btn btn-sm btn-ghost"
                >
                  Next
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.active_account_id

    socket =
      socket
      |> assign(:search, "")
      |> assign(:page, 0)
      |> assign(:per_page, @per_page)
      |> load_data(account_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    account_id = socket.assigns.active_account_id

    socket =
      socket
      |> assign(:search, query)
      |> assign(:page, 0)
      |> load_data(account_id)

    {:noreply, socket}
  end

  def handle_event("next_page", _params, socket) do
    account_id = socket.assigns.active_account_id

    socket =
      socket
      |> assign(:page, socket.assigns.page + 1)
      |> load_data(account_id)

    {:noreply, socket}
  end

  def handle_event("prev_page", _params, socket) do
    account_id = socket.assigns.active_account_id

    socket =
      socket
      |> assign(:page, max(socket.assigns.page - 1, 0))
      |> load_data(account_id)

    {:noreply, socket}
  end

  def handle_event("cancel_customer_subscription", %{"id" => id}, socket) do
    account_id = socket.assigns.active_account_id
    subscription = BillingRepository.get_subscription_by_account_id(String.to_integer(id))

    case subscription do
      nil ->
        {:noreply, put_flash(socket, :error, "Subscription not found")}

      sub ->
        case Billing.cancel_subscription(sub.account_id) do
          :ok ->
            socket =
              socket
              |> load_data(account_id)
              |> put_flash(:info, "Subscription cancelled at period end")

            {:noreply, socket}

          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Failed to cancel: #{reason}")}
        end
    end
  end

  defp load_data(socket, account_id) do
    search = socket.assigns[:search]
    page = socket.assigns[:page] || 0

    subscriptions =
      BillingRepository.list_agency_subscriptions(account_id,
        search: search,
        limit: @per_page,
        offset: page * @per_page
      )

    active_count = BillingRepository.count_active_agency_subscriptions(account_id)
    mrr = BillingRepository.calculate_mrr(account_id)

    past_due_count =
      subscriptions
      |> Enum.count(&(&1.status == :past_due))

    socket
    |> assign(:subscriptions, subscriptions)
    |> assign(:active_count, active_count)
    |> assign(:mrr, mrr)
    |> assign(:past_due_count, past_due_count)
  end

  defp format_mrr(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  defp format_date(nil), do: "—"
  defp format_date(dt), do: Calendar.strftime(dt, "%b %d, %Y")
end
