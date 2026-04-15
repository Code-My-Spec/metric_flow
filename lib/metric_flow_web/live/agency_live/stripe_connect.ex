defmodule MetricFlowWeb.AgencyLive.StripeConnect do
  @moduledoc """
  Stripe Connect onboarding for agency accounts.

  Displays current connection status, initiates Express onboarding,
  and allows disconnection. Only accessible to agency account owners/admins.
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
        Stripe Connect
        <:subtitle>Connect your Stripe account to receive payments</:subtitle>
      </.header>

      <div class="mt-8 space-y-6">
        <div class="card bg-base-100 shadow">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title text-base">Connection Status</h2>
              <span :if={@status == :complete} class="badge badge-success">Connected</span>
              <span :if={@status == :restricted} class="badge badge-warning">Restricted</span>
              <span :if={@status == :not_connected} class="badge badge-ghost">Not connected</span>
            </div>

            <%!-- Not connected state --%>
            <div :if={@status == :not_connected} class="mt-4">
              <p class="text-base-content/60 mb-4">
                Connect your Stripe account to receive subscription payments from your customers.
              </p>
              <button
                phx-click="connect_stripe"
                data-role="connect-stripe"
                class="btn btn-primary"
              >
                Connect Stripe Account
              </button>
            </div>

            <%!-- Connected state --%>
            <div :if={@status == :complete} class="mt-4 space-y-4">
              <div class="space-y-2">
                <div class="flex items-center gap-2">
                  <span class="text-base-content/60">Account ID:</span>
                  <span class="font-mono text-sm">{@stripe_account_id}</span>
                </div>
                <div :if={@capabilities != %{}} class="flex items-center gap-2">
                  <span class="text-base-content/60">Capabilities:</span>
                  <div class="flex gap-1">
                    <span :for={{cap, status} <- @capabilities} class="badge badge-sm badge-outline">
                      {cap}: {status}
                    </span>
                  </div>
                </div>
              </div>

              <div class="divider"></div>

              <div>
                <p class="text-sm text-warning mb-2">
                  Disconnecting will prevent new customer subscriptions through your agency.
                  Existing subscriptions will be flagged for review.
                </p>
                <button
                  phx-click="disconnect_stripe"
                  data-role="disconnect-stripe"
                  data-confirm="Are you sure? This will affect billing for your customers."
                  class="btn btn-error btn-outline btn-sm"
                >
                  Disconnect Stripe Account
                </button>
              </div>
            </div>

            <%!-- Restricted state --%>
            <div :if={@status == :restricted} class="mt-4 space-y-4">
              <div class="alert alert-warning">
                <span>Your Stripe account setup is incomplete. Please complete onboarding to start receiving payments.</span>
              </div>
              <div class="flex items-center gap-2">
                <span class="text-base-content/60">Account ID:</span>
                <span class="font-mono text-sm">{@stripe_account_id}</span>
              </div>
              <button
                phx-click="connect_stripe"
                data-role="connect-stripe"
                class="btn btn-primary btn-sm"
              >
                Resume Onboarding
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

    {:ok, socket}
  end

  @impl true
  def handle_event("connect_stripe", _params, socket) do
    account_id = socket.assigns.active_account_id

    case Billing.create_connect_account(account_id) do
      {:ok, onboarding_url} ->
        {:noreply, redirect(socket, external: onboarding_url)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start Stripe onboarding: #{reason}")}
    end
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

  def handle_event("refresh_status", _params, socket) do
    account_id = socket.assigns.active_account_id
    stripe_account = BillingRepository.get_stripe_account_by_agency(account_id)

    {status, stripe_account_id, capabilities} =
      case stripe_account do
        nil -> {:not_connected, nil, %{}}
        %{onboarding_status: :complete} = sa -> {:complete, sa.stripe_account_id, sa.capabilities || %{}}
        %{onboarding_status: _} = sa -> {:restricted, sa.stripe_account_id, sa.capabilities || %{}}
      end

    socket =
      socket
      |> assign(status: status, stripe_account_id: stripe_account_id, capabilities: capabilities)

    {:noreply, socket}
  end
end
