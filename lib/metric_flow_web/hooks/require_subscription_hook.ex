defmodule MetricFlowWeb.Hooks.RequireSubscriptionHook do
  @moduledoc """
  LiveView on_mount hook that gates access to AI-powered features
  behind an active subscription.

  Free users mount normally but are assigned `:paywall` info instead of
  being redirected, so the paywalled LiveView renders an upgrade modal in
  place of its usual content — no feature data is ever pushed to a free
  user's client, since only what is rendered crosses the socket. Users
  with active or trialing subscriptions, agency admin accounts, and
  agency-customer subscriptions flagged for review (still paying,
  pending their agency's Stripe reconnect) pass through unrestricted.

  A route whose `:id` resolves to a chat session its owner has marked
  shared also passes through unrestricted — a shared insight's recipient
  shouldn't need a subscription of their own just to view it.
  """

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4, push_navigate: 2]

  alias MetricFlow.Ai
  alias MetricFlow.Billing.BillingRepository

  @checkout_path "/app/subscriptions/checkout"
  @default_plan_name "Pro"
  @default_plan_price_cents 4900

  def on_mount(:require_subscription, params, _session, socket) do
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

      viewing_shared_chat_session?(params) ->
        {:cont, socket}

      true ->
        socket =
          socket
          |> assign(:paywall, paywall_info())
          |> attach_hook(:require_subscription_cta, :handle_event, &handle_paywall_event/3)

        {:cont, socket}
    end
  end

  defp handle_paywall_event("paywall_upgrade", _params, socket) do
    {:halt, push_navigate(socket, to: @checkout_path)}
  end

  defp handle_paywall_event(_event, _params, socket), do: {:cont, socket}

  # An agency's Stripe account disconnecting flags its customers' subscriptions
  # `:past_due` for admin review, but those customers are still paying — only a
  # subscription with no agency-managed plan behind it represents a real
  # payment failure that should re-paywall the account.
  defp has_active_subscription?(account_id) do
    case BillingRepository.get_subscription_by_account_id(account_id) do
      %{status: status} when status in [:active, :trialing] ->
        true

      %{status: :past_due, plan: %{agency_account_id: agency_account_id}} ->
        not is_nil(agency_account_id)

      _ ->
        false
    end
  end

  defp viewing_shared_chat_session?(%{"id" => id_string}) do
    case Integer.parse(id_string) do
      {id, ""} -> match?({:ok, _}, Ai.get_shared_chat_session(id))
      _ -> false
    end
  end

  defp viewing_shared_chat_session?(_params), do: false

  defp paywall_info do
    case BillingRepository.list_plans(nil) do
      [plan | _] -> %{plan_name: plan.name, price_text: price_text(plan.price_cents)}
      [] -> %{plan_name: @default_plan_name, price_text: price_text(@default_plan_price_cents)}
    end
  end

  defp price_text(cents), do: "$#{trunc(cents / 100)}/month"
end
