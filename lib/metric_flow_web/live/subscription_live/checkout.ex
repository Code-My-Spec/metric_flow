defmodule MetricFlowWeb.SubscriptionLive.Checkout do
  @moduledoc """
  Subscription checkout flow for direct users and agency customers.

  Displays available plans, initiates Stripe Checkout sessions, and handles
  post-checkout confirmation. Routes payments to platform or agency Stripe
  account based on user's billing context.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Agencies
  alias MetricFlow.Billing
  alias MetricFlow.Billing.BillingRepository

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
        data-role="checkout-root"
        class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden"
      >
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Choose Your Plan
          </p>
          <h1 class="text-2xl font-semibold text-base-content break-words">
            Unlock the AI features with a subscription
          </h1>
          <p class="text-sm text-base-content/70 break-words">
            One flat price, cancel any time from this page.
          </p>
        </header>

        <section
          :if={@subscription}
          data-role="current-subscription"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0 space-y-1">
              <h2 class="text-lg font-semibold text-base-content break-words">
                Current Subscription
              </h2>
              <p
                :if={@subscription.current_period_end}
                class="text-sm text-base-content/70 break-words"
              >
                Current period ends: {Calendar.strftime(
                  @subscription.current_period_end,
                  "%B %d, %Y"
                )}
              </p>
            </div>
            <div class="flex min-w-0 flex-col items-end gap-1">
              <span :if={@subscription.status == :active} class="badge badge-success">Active</span>
              <span :if={@subscription.status == :past_due} class="badge badge-warning">
                Past due
              </span>
              <span :if={@subscription.status == :cancelled} class="badge badge-ghost">
                Cancelled
              </span>
            </div>
          </div>
          <div
            :if={@subscription.status == :active}
            class="mt-4 flex flex-wrap items-center justify-end gap-2"
          >
            <button
              phx-click="cancel_subscription"
              data-confirm="Cancel your subscription? You'll retain access until the end of the current billing period."
              class="rounded-box border border-error bg-base-200 px-3 py-1 text-sm font-semibold text-error hover:bg-base-300"
            >
              Cancel Subscription
            </button>
          </div>
        </section>

        <section
          :if={!@subscription}
          data-role="plans"
          class="grid grid-cols-1 gap-4 sm:grid-cols-2"
        >
          <article
            :for={plan <- @plans}
            data-role="plan-card"
            class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6 space-y-4"
          >
            <div class="space-y-1">
              <h2 class="text-lg font-semibold text-base-content break-words">{plan.name}</h2>
              <p class="text-3xl font-semibold text-base-content break-words">
                {format_price(plan.price_cents, plan.currency)}<span class="text-sm font-normal text-base-content/70">/{plan.billing_interval}</span>
              </p>
              <p :if={plan.description} class="text-sm text-base-content/70 break-words">
                {plan.description}
              </p>
            </div>
            <ul class="space-y-1 text-sm text-base-content/80">
              <li>Correlations</li>
              <li>Intelligence</li>
              <li>Visualizations</li>
            </ul>
            <div>
              <button
                :if={@billing_available?}
                phx-click="subscribe"
                phx-value-plan-id={plan.id}
                data-role="subscribe-button"
                class="btn-brand-gradient rounded-box w-full px-4 py-2 font-semibold text-base-content"
              >
                Subscribe for {format_price(plan.price_cents, plan.currency)}/{plan.billing_interval}
              </button>
              <p :if={!@billing_available?} class="text-sm text-base-content/70 break-words">
                Billing is currently unavailable for this plan. Please contact support.
              </p>
            </div>
          </article>
        </section>

        <section
          :if={!@subscription && @plans == []}
          data-role="no-plans"
          class="rounded-box border border-neutral bg-base-200 p-6 text-center"
        >
          <p class="text-base font-semibold text-base-content">No plans available</p>
          <p class="mt-1 text-sm text-base-content/70">Please contact support.</p>
        </section>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.active_account_id

    subscription = BillingRepository.get_subscription_by_account_id(account_id)
    plans = load_plans(account_id)

    socket =
      socket
      |> assign(:subscription, subscription)
      |> assign(:plans, plans)
      |> assign(:billing_available?, billing_available?(plans))

    {:ok, socket}
  end

  @impl true
  def handle_event("subscribe", %{"plan-id" => plan_id}, socket) do
    account_id = socket.assigns.active_account_id
    plan = BillingRepository.get_plan(String.to_integer(plan_id))

    return_url = MetricFlowWeb.Endpoint.url() <> "/app/subscriptions/checkout"

    case Billing.create_checkout_session(account_id, plan, return_url) do
      {:ok, checkout_url} ->
        {:noreply, redirect(socket, external: checkout_url)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start checkout: #{reason}")}
    end
  end

  def handle_event("subscribe", _params, socket) do
    {:noreply, put_flash(socket, :error, "Please select a plan")}
  end

  def handle_event("cancel_subscription", _params, socket) do
    account_id = socket.assigns.active_account_id

    case Billing.cancel_subscription(account_id) do
      :ok ->
        subscription = BillingRepository.get_subscription_by_account_id(account_id)

        socket =
          socket
          |> assign(:subscription, subscription)
          |> put_flash(:info, "Subscription will be cancelled at end of billing period")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel: #{reason}")}
    end
  end

  defp load_plans(account_id) do
    case Agencies.find_client_agency_account_id(account_id) do
      nil ->
        # Not a client of any agency: either this account is itself an
        # agency with plans of its own, or a plain account with none —
        # either way, nothing found here falls back to the platform's.
        self_plans = BillingRepository.list_plans(account_id)
        if self_plans != [], do: self_plans, else: BillingRepository.list_plans(nil)

      agency_account_id ->
        # A client of an agency sees only that agency's plans. An empty
        # list means the agency hasn't configured one yet — never fall
        # back to the platform catalog or another agency's plans.
        BillingRepository.list_plans(agency_account_id)
    end
  end

  # Platform plans (agency_account_id: nil) always bill through the platform's
  # own Stripe account. Agency plans require that agency to have completed
  # Stripe Connect onboarding first, since checkout has nowhere else to route
  # the payment.
  defp billing_available?([%{agency_account_id: agency_account_id} | _])
       when not is_nil(agency_account_id) do
    match?(
      %{onboarding_status: :complete},
      BillingRepository.get_stripe_account_by_agency(agency_account_id)
    )
  end

  defp billing_available?(_plans), do: true

  defp format_price(cents, currency) do
    dollars = cents / 100
    symbol = currency_symbol(currency)
    "#{symbol}#{:erlang.float_to_binary(dollars, decimals: 2)}"
  end

  defp currency_symbol("usd"), do: "$"
  defp currency_symbol("eur"), do: "€"
  defp currency_symbol("gbp"), do: "£"
  defp currency_symbol(_), do: "$"
end
