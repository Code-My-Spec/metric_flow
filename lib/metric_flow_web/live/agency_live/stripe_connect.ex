defmodule MetricFlowWeb.AgencyLive.StripeConnect do
  @moduledoc """
  Stripe Connect onboarding for agency accounts.

  Displays current connection status, initiates Express onboarding,
  and allows disconnection. Only accessible to agency account owners/admins.
  """

  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
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
        data-role="agency-stripe-connect-root"
        class="mx-auto w-full max-w-3xl space-y-6 overflow-x-hidden"
      >
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Payments
          </p>
          <h1 class="text-2xl font-semibold text-base-content break-words">
            Stripe Connect
          </h1>
          <p class="text-sm text-base-content/70 break-words">
            {headline_description(@status)}
          </p>
        </header>

        <section
          data-role="stripe-connection-status"
          data-status={@status}
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6 space-y-4"
        >
          <div class="flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0 space-y-1">
              <h2 class="text-lg font-semibold text-base-content">Connection Status</h2>
              <p class="text-sm text-base-content/70 break-words">
                {status_detail(@status)}
              </p>
            </div>
            <span :if={@status == :complete} class="badge badge-success">Connected</span>
            <span :if={@status == :restricted} class="badge badge-warning">Restricted</span>
            <span :if={@status == :not_connected} class="badge badge-ghost">Not connected</span>
          </div>

          <div :if={@status in [:complete, :restricted]} class="space-y-2">
            <div class="flex flex-wrap items-baseline gap-2">
              <span class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                Account ID
              </span>
              <span class="font-mono text-sm text-base-content break-all">
                {@stripe_account_id}
              </span>
            </div>
            <div :if={@capabilities != %{}} class="space-y-1">
              <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
                Capabilities
              </p>
              <div class="flex flex-wrap gap-1">
                <span
                  :for={{cap, cap_status} <- @capabilities}
                  class="badge badge-sm badge-outline break-all"
                >
                  {cap}: {cap_status}
                </span>
              </div>
            </div>
          </div>

          <div
            :if={@status == :not_connected and @is_admin}
            data-role="stripe-next-action"
            class="pt-2"
          >
            <button
              phx-click="connect_stripe"
              data-role="connect-stripe"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
            >
              Connect Stripe Account
            </button>
          </div>

          <div
            :if={@status == :restricted and @is_admin}
            data-role="stripe-next-action"
            class="pt-2"
          >
            <button
              phx-click="connect_stripe"
              data-role="connect-stripe"
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
            >
              Resume Onboarding
            </button>
          </div>

          <div
            :if={@status == :complete and @is_admin}
            data-role="stripe-next-action"
            class="space-y-2 border-t border-neutral pt-4"
          >
            <p class="text-sm text-warning break-words">
              Disconnecting will prevent new customer subscriptions through your agency. Existing subscriptions will be flagged for review.
            </p>
            <button
              phx-click="disconnect_stripe"
              data-role="disconnect-stripe"
              class="w-full rounded-box border border-error bg-base-200 px-4 py-2 text-sm font-semibold text-error hover:bg-base-300 sm:w-auto"
            >
              Disconnect Stripe Account
            </button>
          </div>

          <p :if={not @is_admin} class="text-sm text-base-content/60 break-words">
            Ask an account owner or admin to {non_admin_action(@status)}.
          </p>
        </section>
      </main>
    </Layouts.app>
    """
  end

  defp headline_description(:complete) do
    "Stripe is connected. Subscription payments from your clients route straight to this agency."
  end

  defp headline_description(:restricted) do
    "Stripe onboarding started but isn't finished. Payouts stay on hold until you complete it."
  end

  defp headline_description(:not_connected) do
    "Connect your Stripe account so subscription payments from your clients land in your bank, not the platform's."
  end

  defp status_detail(:complete),
    do: "Subscriptions bill through this Stripe account."

  defp status_detail(:restricted),
    do: "Stripe needs a few more details before payouts can start."

  defp status_detail(:not_connected),
    do: "Client subscriptions fall back to the platform's Stripe account until you connect one."

  defp non_admin_action(:complete), do: "manage the Stripe connection"
  defp non_admin_action(:restricted), do: "finish Stripe onboarding"
  defp non_admin_action(:not_connected), do: "connect Stripe"

  @impl true
  def mount(_params, _session, socket) do
    account_id = socket.assigns.active_account_id
    scope = socket.assigns.current_scope
    is_admin = Accounts.get_user_role(scope, scope.user.id, account_id) in [:owner, :admin]
    stripe_account = BillingRepository.get_stripe_account_by_agency(account_id)

    {status, stripe_account_id, capabilities} =
      case stripe_account do
        nil ->
          {:not_connected, nil, %{}}

        %{onboarding_status: :complete} = sa ->
          {:complete, sa.stripe_account_id, sa.capabilities || %{}}

        %{onboarding_status: _} = sa ->
          {:restricted, sa.stripe_account_id, sa.capabilities || %{}}
      end

    socket =
      socket
      |> assign(:status, status)
      |> assign(:stripe_account_id, stripe_account_id)
      |> assign(:capabilities, capabilities)
      |> assign(:is_admin, is_admin)

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_stripe", _params, %{assigns: %{is_admin: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("connect_stripe", _params, socket) do
    account_id = socket.assigns.active_account_id

    case Billing.create_connect_account(account_id) do
      {:ok, onboarding_url} ->
        {:noreply, redirect(socket, external: onboarding_url)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start Stripe onboarding: #{reason}")}
    end
  end

  def handle_event("disconnect_stripe", _params, %{assigns: %{is_admin: false}} = socket) do
    {:noreply, socket}
  end

  def handle_event("disconnect_stripe", _params, socket) do
    account_id = socket.assigns.active_account_id

    case Billing.disconnect_stripe_account(account_id) do
      :ok ->
        socket =
          socket
          |> assign(status: :not_connected, stripe_account_id: nil, capabilities: %{})
          |> put_flash(:info, "Stripe account disconnected")

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect: #{reason}")}
    end
  end
end
