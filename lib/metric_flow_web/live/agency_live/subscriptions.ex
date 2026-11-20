defmodule MetricFlowWeb.AgencyLive.Subscriptions do
  @moduledoc """
  Agency customer subscription management dashboard.

  Displays subscriptions across the agency's client accounts with
  summary stats, search, pagination, and cancel actions.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Billing
  alias MetricFlow.Billing.BillingRepository

  @per_page 20
  @problem_statuses [:past_due, :incomplete]

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
      <main
        data-role="agency-subscriptions-root"
        class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden"
      >
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Customer Subscriptions
          </p>
          <h1 class="text-2xl font-semibold text-base-content break-words">
            Watch your clients' subscriptions
          </h1>
          <p class="text-sm text-base-content/70 break-words">
            Problem subscriptions lead the list; healthy ones follow. Cancel an active subscription from its card, or search by customer ID or email.
          </p>
        </header>

        <section
          data-role="subscriptions-summary"
          class="grid grid-cols-1 gap-3 sm:grid-cols-3"
        >
          <div
            data-role="summary-active"
            class="rounded-box border border-neutral bg-base-200 p-4"
          >
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Active Subscribers
            </p>
            <p class="mt-1 text-2xl font-semibold text-base-content">{@active_count}</p>
          </div>
          <div
            data-role="summary-mrr"
            class="rounded-box border border-neutral bg-base-200 p-4"
          >
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">MRR</p>
            <p class="mt-1 text-2xl font-semibold text-base-content">{format_mrr(@mrr)}</p>
          </div>
          <div
            data-role="summary-past-due"
            class={[
              "rounded-box border bg-base-200 p-4",
              if(@past_due_count > 0, do: "border-error", else: "border-neutral")
            ]}
          >
            <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
              Past Due
            </p>
            <p class={[
              "mt-1 text-2xl font-semibold",
              if(@past_due_count > 0, do: "text-error", else: "text-base-content")
            ]}>
              {@past_due_count}
            </p>
          </div>
        </section>

        <section class="rounded-box border border-neutral bg-base-200 p-4">
          <form phx-change="search" phx-submit="search" class="space-y-1">
            <label
              for="subscription-search-input"
              class="block text-sm font-semibold text-base-content"
            >
              Search customers
            </label>
            <input
              id="subscription-search-input"
              type="text"
              name="query"
              value={@search}
              placeholder="Search by customer ID or email..."
              class="input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
              phx-debounce="300"
            />
          </form>
        </section>

        <section data-role="subscriptions-list" class="space-y-3">
          <div
            :if={@subscriptions == []}
            class="rounded-box border border-neutral bg-base-200 p-6 text-center"
          >
            <p class="text-base font-semibold text-base-content">
              No customer subscriptions yet
            </p>
            <p class="mt-1 text-sm text-base-content/70">
              Client subscriptions appear here as soon as a customer signs up to one of your plans.
            </p>
          </div>

          <article
            :for={sub <- @subscriptions}
            data-role="subscription-row"
            data-status={sub.status}
            class={[
              "rounded-box border bg-base-200 p-4 sm:p-6",
              if(sub.status in @problem_statuses, do: "border-error", else: "border-neutral")
            ]}
          >
            <div class="flex flex-wrap items-start justify-between gap-3">
              <div class="min-w-0 space-y-1">
                <p class="font-mono text-sm text-base-content break-all">
                  {sub.stripe_customer_id}
                </p>
                <p class="text-sm text-base-content/70 break-words">
                  {if sub.plan, do: sub.plan.name, else: "—"}
                </p>
              </div>
              <div class="flex min-w-0 flex-col items-end gap-1">
                <span :if={sub.status == :active} class="badge badge-success">Active</span>
                <span :if={sub.status == :past_due} class="badge badge-warning">Past due</span>
                <span :if={sub.status == :cancelled} class="badge badge-ghost">Cancelled</span>
                <span :if={sub.status == :trialing} class="badge badge-info">Trialing</span>
                <span :if={sub.status == :incomplete} class="badge badge-warning">Incomplete</span>
              </div>
            </div>

            <dl class="mt-4 grid grid-cols-1 gap-2 text-sm sm:grid-cols-2">
              <div class="min-w-0">
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Start Date</dt>
                <dd class="text-base-content break-words">{format_date(sub.inserted_at)}</dd>
              </div>
              <div class="min-w-0">
                <dt class="text-xs uppercase tracking-wide text-base-content/60">Period End</dt>
                <dd class="text-base-content break-words">{format_date(sub.current_period_end)}</dd>
              </div>
            </dl>

            <div
              :if={sub.status == :active and @is_admin}
              class="mt-4 flex flex-wrap items-center justify-end gap-2"
            >
              <button
                phx-click="cancel_customer_subscription"
                phx-value-id={sub.id}
                data-confirm="Cancel this customer's subscription at period end?"
                class="rounded-box border border-error bg-base-200 px-3 py-1 text-xs font-semibold text-error hover:bg-base-300"
              >
                Cancel
              </button>
            </div>
          </article>

          <nav
            :if={@subscriptions != []}
            aria-label="Pagination"
            class="flex flex-wrap items-center justify-center gap-2 pt-2"
          >
            <button
              :if={@page > 0}
              phx-click="prev_page"
              class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-sm text-base-content hover:bg-base-300"
            >
              Previous
            </button>
            <span class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-sm text-base-content/70">
              Page {@page + 1}
            </span>
            <button
              :if={length(@subscriptions) == @per_page}
              phx-click="next_page"
              class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-sm text-base-content hover:bg-base-300"
            >
              Next
            </button>
          </nav>
        </section>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.active_account_id
    scope = socket.assigns.current_scope
    is_admin = Accounts.get_user_role(scope, scope.user.id, account_id) in [:owner, :admin]

    socket =
      socket
      |> assign(:search, "")
      |> assign(:page, 0)
      |> assign(:per_page, @per_page)
      |> assign(:problem_statuses, @problem_statuses)
      |> assign(:is_admin, is_admin)
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

  def handle_event(
        "cancel_customer_subscription",
        _params,
        %{assigns: %{is_admin: false}} = socket
      ) do
    {:noreply, socket}
  end

  def handle_event("cancel_customer_subscription", %{"id" => id}, socket) do
    account_id = socket.assigns.active_account_id
    subscription = BillingRepository.get_agency_subscription(account_id, String.to_integer(id))

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
      account_id
      |> BillingRepository.list_agency_subscriptions(
        search: search,
        limit: @per_page,
        offset: page * @per_page
      )
      |> sort_problems_first()

    active_count = BillingRepository.count_active_agency_subscriptions(account_id)
    mrr = BillingRepository.calculate_mrr(account_id)
    past_due_count = BillingRepository.count_past_due_agency_subscriptions(account_id)

    socket
    |> assign(:subscriptions, subscriptions)
    |> assign(:active_count, active_count)
    |> assign(:mrr, mrr)
    |> assign(:past_due_count, past_due_count)
  end

  defp sort_problems_first(subscriptions) do
    Enum.sort_by(subscriptions, &status_rank(&1.status))
  end

  defp status_rank(status) when status in @problem_statuses, do: 0
  defp status_rank(:active), do: 1
  defp status_rank(:trialing), do: 1
  defp status_rank(:cancelled), do: 2
  defp status_rank(_), do: 3

  defp format_mrr(cents) do
    dollars = cents / 100
    "$#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  defp format_date(nil), do: "—"
  defp format_date(dt), do: Calendar.strftime(dt, "%b %d, %Y")
end
