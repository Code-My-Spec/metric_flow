defmodule MetricFlow.Billing.WebhookProcessor do
  @moduledoc """
  Processes verified Stripe webhook events.

  Handles subscription lifecycle events and Connect account updates,
  persisting state changes via BillingRepository.
  """

  require Logger

  alias MetricFlow.Billing.BillingRepository

  @spec process_event(map()) :: :ok | {:error, term()}

  def process_event(%{"type" => "customer.subscription.created", "data" => %{"object" => object}}) do
    upsert_subscription(object)
  end

  def process_event(%{"type" => "customer.subscription.updated", "data" => %{"object" => object}}) do
    upsert_subscription(object)
  end

  def process_event(%{"type" => "customer.subscription.deleted", "data" => %{"object" => object}}) do
    attrs = %{
      stripe_subscription_id: object["id"],
      stripe_customer_id: object["customer"],
      status: :cancelled,
      cancelled_at: parse_timestamp(object["canceled_at"]),
      account_id: extract_account_id(object)
    }

    case BillingRepository.upsert_subscription(attrs) do
      {:ok, _subscription} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def process_event(%{"type" => "invoice.payment_failed", "data" => %{"object" => object}}) do
    stripe_sub_id = object["subscription"]

    case BillingRepository.get_subscription_by_stripe_id(stripe_sub_id) do
      nil ->
        Logger.warning("Webhook: invoice.payment_failed for unknown subscription #{stripe_sub_id}")
        :ok

      subscription ->
        case BillingRepository.upsert_subscription(%{
               stripe_subscription_id: subscription.stripe_subscription_id,
               stripe_customer_id: subscription.stripe_customer_id,
               status: :past_due,
               account_id: subscription.account_id
             }) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def process_event(%{"type" => "account.updated", "data" => %{"object" => object}}) do
    stripe_account_id = object["id"]
    charges_enabled = object["charges_enabled"]
    payouts_enabled = object["payouts_enabled"]
    details_submitted = object["details_submitted"]

    onboarding_status = determine_onboarding_status(charges_enabled, payouts_enabled, details_submitted)

    case BillingRepository.get_stripe_account_by_stripe_id(stripe_account_id) do
      nil ->
        Logger.warning("Webhook: account.updated for unknown Stripe account #{stripe_account_id}")
        :ok

      existing ->
        case BillingRepository.upsert_stripe_account(%{
               stripe_account_id: stripe_account_id,
               agency_account_id: existing.agency_account_id,
               onboarding_status: onboarding_status,
               capabilities: %{
                 charges_enabled: charges_enabled,
                 payouts_enabled: payouts_enabled,
                 details_submitted: details_submitted
               }
             }) do
          {:ok, _} -> :ok
          {:error, reason} -> {:error, reason}
        end
    end
  end

  def process_event(%{"type" => type}) do
    Logger.debug("Webhook: ignoring unhandled event type #{type}")
    :ok
  end

  # -- Private --

  defp upsert_subscription(object) do
    attrs = %{
      stripe_subscription_id: object["id"],
      stripe_customer_id: object["customer"],
      status: normalize_status(object["status"]),
      current_period_start: parse_timestamp(object["current_period_start"]),
      current_period_end: parse_timestamp(object["current_period_end"]),
      account_id: extract_account_id(object)
    }

    case BillingRepository.upsert_subscription(attrs) do
      {:ok, _subscription} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_status("active"), do: :active
  defp normalize_status("past_due"), do: :past_due
  defp normalize_status("canceled"), do: :cancelled
  defp normalize_status("trialing"), do: :trialing
  defp normalize_status("incomplete"), do: :incomplete
  defp normalize_status(_), do: :active

  defp extract_account_id(%{"metadata" => %{"account_id" => id}}) when is_binary(id) do
    String.to_integer(id)
  end

  defp extract_account_id(_), do: nil

  defp parse_timestamp(nil), do: nil
  defp parse_timestamp(ts) when is_integer(ts), do: DateTime.from_unix!(ts)

  defp determine_onboarding_status(true, true, true), do: :complete
  defp determine_onboarding_status(_, _, _), do: :pending
end
