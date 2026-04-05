defmodule MetricFlow.Billing do
  @moduledoc """
  Subscription billing and payment processing via Stripe.

  Manages direct user subscriptions, agency Stripe Connect onboarding,
  agency-defined subscription plans, and webhook event processing.
  All public functions accept a `%Scope{}` as the first parameter
  for multi-tenant isolation where applicable.
  """

  use Boundary, deps: [MetricFlow], exports: []

  require Logger

  alias MetricFlow.Billing.BillingRepository

  @doc """
  Process a verified Stripe webhook event.

  Dispatches to the appropriate handler based on event type.
  Returns :ok for recognized events and {:ok, :ignored} for unrecognized types.
  """
  @spec process_webhook_event(map()) :: :ok | {:ok, :ignored} | {:error, term()}
  def process_webhook_event(%{"type" => type} = event) do
    case type do
      "customer.subscription." <> _ ->
        handle_subscription_event(event)

      "invoice.payment_failed" ->
        handle_payment_failed(event)

      "invoice.payment_succeeded" ->
        handle_payment_succeeded(event)

      "account.updated" ->
        handle_account_updated(event)

      _unrecognized ->
        Logger.debug("Ignoring unrecognized Stripe event type: #{type}")
        {:ok, :ignored}
    end
  end

  def process_webhook_event(_invalid), do: {:error, :invalid_event}

  defp handle_subscription_event(%{"type" => "customer.subscription.created"} = event) do
    sub = event["data"]["object"]
    Logger.info("Processing subscription.created: #{sub["id"]}")

    BillingRepository.upsert_subscription(%{
      stripe_subscription_id: sub["id"],
      stripe_customer_id: sub["customer"],
      status: map_status(sub["status"]),
      current_period_start: from_unix(sub["current_period_start"]),
      current_period_end: from_unix(sub["current_period_end"])
    })

    :ok
  end

  defp handle_subscription_event(%{"type" => "customer.subscription.updated"} = event) do
    sub = event["data"]["object"]
    Logger.info("Processing subscription.updated: #{sub["id"]}")

    BillingRepository.upsert_subscription(%{
      stripe_subscription_id: sub["id"],
      stripe_customer_id: sub["customer"],
      status: map_status(sub["status"]),
      current_period_start: from_unix(sub["current_period_start"]),
      current_period_end: from_unix(sub["current_period_end"])
    })

    :ok
  end

  defp handle_subscription_event(%{"type" => "customer.subscription.deleted"} = event) do
    sub = event["data"]["object"]
    Logger.info("Processing subscription.deleted: #{sub["id"]}")

    BillingRepository.upsert_subscription(%{
      stripe_subscription_id: sub["id"],
      stripe_customer_id: sub["customer"],
      status: :cancelled,
      cancelled_at: from_unix(sub["canceled_at"]),
      current_period_end: from_unix(sub["current_period_end"])
    })

    :ok
  end

  defp handle_subscription_event(%{"type" => type}) do
    Logger.debug("Ignoring subscription event subtype: #{type}")
    {:ok, :ignored}
  end

  defp handle_payment_failed(event) do
    sub_id = event["data"]["object"]["subscription"]
    Logger.info("Processing invoice.payment_failed for subscription: #{sub_id}")

    case BillingRepository.get_subscription_by_stripe_id(sub_id) do
      nil ->
        Logger.warning("No subscription found for #{sub_id}")
        :ok

      subscription ->
        subscription
        |> MetricFlow.Billing.Subscription.changeset(%{status: :past_due})
        |> MetricFlow.Repo.update()

        :ok
    end
  end

  defp handle_payment_succeeded(event) do
    Logger.info("Processing invoice.payment_succeeded: #{event["data"]["object"]["id"]}")
    :ok
  end

  defp handle_account_updated(event) do
    account = event["data"]["object"]
    Logger.info("Processing account.updated: #{account["id"]}")

    if account["id"] do
      BillingRepository.upsert_stripe_account(%{
        stripe_account_id: account["id"],
        onboarding_status: if(account["charges_enabled"], do: :complete, else: :restricted),
        capabilities: account["capabilities"] || %{}
      })
    end

    :ok
  end

  @doc """
  Create a Stripe Checkout session and return the checkout URL.
  """
  @spec create_checkout_session(integer(), map(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def create_checkout_session(account_id, plan, return_url) do
    alias MetricFlow.Billing.StripeClient

    # Determine if this is an agency plan (route to agency Stripe account)
    stripe_account =
      if plan.agency_account_id do
        case BillingRepository.get_stripe_account_by_agency(plan.agency_account_id) do
          %{stripe_account_id: id} -> id
          nil -> nil
        end
      end

    case StripeClient.create_checkout_session(plan, return_url, stripe_account: stripe_account) do
      {:ok, session} -> {:ok, session["url"]}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Cancel a subscription at period end.
  """
  @spec cancel_subscription(integer()) :: :ok | {:error, term()}
  def cancel_subscription(account_id) do
    alias MetricFlow.Billing.StripeClient

    case BillingRepository.get_subscription_by_account_id(account_id) do
      nil ->
        {:error, :no_subscription}

      subscription ->
        case StripeClient.cancel_subscription(subscription.stripe_subscription_id) do
          {:ok, _} ->
            subscription
            |> MetricFlow.Billing.Subscription.changeset(%{
              status: :cancelled,
              cancelled_at: DateTime.utc_now()
            })
            |> MetricFlow.Repo.update()

            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  @doc """
  Create a Stripe Connect Express account and return the onboarding URL.
  """
  @spec create_connect_account(integer()) :: {:ok, String.t()} | {:error, term()}
  def create_connect_account(account_id) do
    alias MetricFlow.Billing.StripeClient

    with {:ok, account} <- StripeClient.create_express_account(),
         stripe_account_id <- account["id"],
         {:ok, _} <-
           BillingRepository.upsert_stripe_account(%{
             stripe_account_id: stripe_account_id,
             agency_account_id: account_id,
             onboarding_status: :pending
           }),
         {:ok, link} <- StripeClient.create_account_link(stripe_account_id) do
      {:ok, link["url"]}
    end
  end

  @doc """
  Disconnect an agency's Stripe account.
  """
  @spec disconnect_stripe_account(integer()) :: :ok | {:error, term()}
  def disconnect_stripe_account(account_id) do
    case BillingRepository.get_stripe_account_by_agency(account_id) do
      nil ->
        {:error, :not_connected}

      stripe_account ->
        case MetricFlow.Repo.delete(stripe_account) do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, changeset}
        end
    end
  end

  defp map_status("active"), do: :active
  defp map_status("past_due"), do: :past_due
  defp map_status("canceled"), do: :cancelled
  defp map_status("trialing"), do: :trialing
  defp map_status("incomplete"), do: :incomplete
  defp map_status(_), do: :active

  defp from_unix(nil), do: nil
  defp from_unix(timestamp) when is_integer(timestamp) do
    DateTime.from_unix!(timestamp)
  end
  defp from_unix(_), do: nil
end
