defmodule MetricFlowWeb.Hooks.RequireSubscriptionHook do
  @moduledoc """
  LiveView on_mount hook that gates access to AI-powered features
  behind an active subscription.

  Free users are redirected to `/subscriptions/checkout` with a flash
  message prompting them to upgrade. Users with active or trialing
  subscriptions pass through unrestricted.
  """

  import Phoenix.LiveView, only: [redirect: 2, put_flash: 3]

  alias MetricFlow.Billing.BillingRepository

  def on_mount(:require_subscription, _params, _session, socket) do
    scope = socket.assigns[:current_scope]
    account_id = socket.assigns[:active_account_id]
    account_type = socket.assigns[:active_account_type]

    cond do
      is_nil(scope) or is_nil(account_id) ->
        {:cont, socket}

      account_type == :agency ->
        {:cont, socket}

      has_active_subscription?(account_id) ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> put_flash(:error, "Upgrade to access AI features")
          |> redirect(to: "/app/subscriptions/checkout")

        {:halt, socket}
    end
  end

  defp has_active_subscription?(account_id) do
    case BillingRepository.get_subscription_by_account_id(account_id) do
      %{status: status} when status in [:active, :trialing] -> true
      _ -> false
    end
  end
end
