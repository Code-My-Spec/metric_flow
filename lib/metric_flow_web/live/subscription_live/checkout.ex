defmodule MetricFlowWeb.SubscriptionLive.Checkout do
  @moduledoc """
  Subscription checkout flow for direct users and agency customers.

  Displays available plans, initiates Stripe Checkout sessions, and handles
  post-checkout confirmation. Routes payments to platform or agency Stripe
  account based on user's billing context.
  """

  use MetricFlowWeb, :live_view

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
    >
    <div class="mx-auto">
      <.header>
        Choose Your Plan
        <:subtitle>Unlock AI features with a subscription</:subtitle>
      </.header>

      <div class="mt-8 space-y-6">
        <%!-- Active subscription display --%>
        <div :if={@subscription} class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title text-base">Current Subscription</h2>
              <span :if={@subscription.status == :active} class="badge badge-success">Active</span>
              <span :if={@subscription.status == :past_due} class="badge badge-warning">Past due</span>
              <span :if={@subscription.status == :cancelled} class="badge badge-ghost">Cancelled</span>
            </div>
            <div class="mt-2 space-y-1 text-sm text-base-content/60">
              <p :if={@subscription.current_period_end}>
                Current period ends: {Calendar.strftime(@subscription.current_period_end, "%B %d, %Y")}
              </p>
            </div>
            <div :if={@subscription.status == :active} class="card-actions justify-end mt-4">
              <button
                phx-click="cancel_subscription"
                data-confirm="Cancel your subscription? You'll retain access until the end of the current billing period."
                class="btn btn-error btn-outline btn-sm"
              >
                Cancel Subscription
              </button>
            </div>
          </div>
        </div>

        <%!-- Plan cards --%>
        <div :if={!@subscription} class="grid gap-6 md:grid-cols-2">
          <div :for={plan <- @plans} class="card bg-base-100 shadow">
            <div class="card-body text-center">
              <h2 class="card-title justify-center">{plan.name}</h2>
              <p class="text-3xl font-bold">
                {format_price(plan.price_cents, plan.currency)}
                <span class="text-sm font-normal">/{plan.billing_interval}</span>
              </p>
              <p :if={plan.description} class="text-base-content/60">{plan.description}</p>
              <ul class="text-left text-sm space-y-1 mt-2">
                <li>Correlations</li>
                <li>Intelligence</li>
                <li>Visualizations</li>
              </ul>
              <div class="card-actions justify-center mt-4">
                <button
                  phx-click="subscribe"
                  phx-value-plan-id={plan.id}
                  data-role="subscribe-button"
                  class="btn btn-primary"
                >
                  Subscribe
                </button>
              </div>
            </div>
          </div>
        </div>

        <%!-- No plans available --%>
        <div :if={!@subscription && @plans == []} class="card bg-base-100 shadow">
          <div class="card-body text-center">
            <h2 class="card-title justify-center">MetricFlow Pro</h2>
            <p class="text-3xl font-bold">$49.99<span class="text-sm font-normal">/month</span></p>
            <p class="text-base-content/60">Correlations, Intelligence, and Visualizations</p>
            <div class="card-actions justify-center mt-4">
              <p class="text-sm text-base-content/60">No plans available. Please contact support.</p>
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

    subscription = BillingRepository.get_subscription_by_account_id(account_id)
    plans = load_plans(account_id)

    socket =
      socket
      |> assign(:subscription, subscription)
      |> assign(:plans, plans)

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
    # Check if user is under an agency with plans
    agency_plans = BillingRepository.list_plans(account_id)

    if agency_plans != [] do
      agency_plans
    else
      # Fall back to platform plans
      BillingRepository.list_plans(nil)
    end
  end

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
