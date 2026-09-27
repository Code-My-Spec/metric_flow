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

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Billing.BillingNotifier
  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Billing.StripeAccount
  alias MetricFlow.Billing.Subscription
  alias MetricFlow.Users

  @doc """
  Process a verified Stripe webhook event.

  Dispatches to the appropriate handler based on event type.
  Returns :ok for recognized events and {:ok, :ignored} for unrecognized types.
  """
  @spec process_webhook_event(map()) ::
          :ok | {:ok, :ignored} | {:ok, :duplicate} | {:error, term()}
  def process_webhook_event(%{"type" => type, "id" => event_id} = event) do
    case BillingRepository.mark_event_processed(event_id, type) do
      {:error, %Ecto.Changeset{} = changeset} ->
        if Keyword.has_key?(changeset.errors, :stripe_event_id) do
          {:ok, :duplicate}
        else
          {:error, changeset}
        end

      {:ok, processed_event} ->
        case resolve_account(event) do
          {:ok, account_id} ->
            result = dispatch_event(type, event, account_id)
            BillingRepository.record_event_outcome(processed_event, outcome_status(result))
            result

          {:error, :unrecognized_account} = error ->
            BillingRepository.record_event_outcome(processed_event, :failed)
            error
        end
    end
  end

  def process_webhook_event(_invalid), do: {:error, :invalid_event}

  defp outcome_status(:ok), do: :processed
  defp outcome_status({:ok, _}), do: :processed
  defp outcome_status({:error, _}), do: :failed

  defp dispatch_event(type, event, account_id) do
    case type do
      "customer.subscription." <> _ ->
        handle_subscription_event(event, account_id)

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

  # A connected-account event is attributed to the specific account named in
  # the subscription's own metadata (set at checkout) when present, and
  # otherwise falls back to the agency that owns the connected Stripe
  # account, since that is the only account context Stripe gives us.
  defp resolve_account(%{"account" => connected_account_id} = event)
       when is_binary(connected_account_id) do
    case BillingRepository.get_stripe_account_by_stripe_id(connected_account_id) do
      nil ->
        {:error, :unrecognized_account}

      %StripeAccount{agency_account_id: agency_account_id} ->
        {:ok, metadata_account_id(event) || agency_account_id}
    end
  end

  defp resolve_account(event), do: {:ok, metadata_account_id(event)}

  defp metadata_account_id(%{"data" => %{"object" => %{"metadata" => %{"account_id" => id}}}})
       when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _ -> nil
    end
  end

  defp metadata_account_id(_), do: nil

  defp handle_subscription_event(%{"type" => "customer.subscription.created"} = event, account_id) do
    sub = event["data"]["object"]
    Logger.info("Processing subscription.created: #{sub["id"]}")

    persist_subscription(%{
      stripe_subscription_id: sub["id"],
      stripe_customer_id: sub["customer"],
      status: map_status(sub["status"]),
      current_period_start: from_unix(sub["current_period_start"]),
      current_period_end: from_unix(sub["current_period_end"]),
      account_id: account_id
    })
  end

  defp handle_subscription_event(%{"type" => "customer.subscription.updated"} = event, account_id) do
    sub = event["data"]["object"]
    Logger.info("Processing subscription.updated: #{sub["id"]}")

    persist_subscription(%{
      stripe_subscription_id: sub["id"],
      stripe_customer_id: sub["customer"],
      status: map_status(sub["status"]),
      current_period_start: from_unix(sub["current_period_start"]),
      current_period_end: from_unix(sub["current_period_end"]),
      account_id: resolve_update_account_id(sub["id"], account_id)
    })
  end

  defp handle_subscription_event(%{"type" => "customer.subscription.deleted"} = event, account_id) do
    sub = event["data"]["object"]
    Logger.info("Processing subscription.deleted: #{sub["id"]}")

    # Downgrade to free: clear the plan association. Stripe only sends
    # `deleted` once the subscription has actually ended (immediately, or
    # at the configured period end for cancel_at_period_end cancellations),
    # so no separate period-end scheduling is needed here.
    persist_subscription(%{
      stripe_subscription_id: sub["id"],
      stripe_customer_id: sub["customer"],
      status: :cancelled,
      cancelled_at: from_unix(sub["canceled_at"]),
      current_period_end: from_unix(sub["current_period_end"]),
      account_id: resolve_update_account_id(sub["id"], account_id),
      plan_id: nil
    })
  end

  defp handle_subscription_event(%{"type" => type}, _account_id) do
    Logger.debug("Ignoring subscription event subtype: #{type}")
    {:ok, :ignored}
  end

  # An update/delete event with no resolvable account_id (metadata stripped
  # or predates the metadata convention) must not overwrite an
  # already-attributed subscription's account_id with nil — that is the
  # only field distinguishing "unattributed" from "just needs a status
  # refresh". A truly new subscription with no resolvable account still
  # fails the changeset's `validate_required(:account_id)`, which is
  # correct: there is nothing to fall back to.
  defp resolve_update_account_id(_stripe_subscription_id, account_id) when not is_nil(account_id),
    do: account_id

  defp resolve_update_account_id(stripe_subscription_id, nil) do
    case BillingRepository.get_subscription_by_stripe_id(stripe_subscription_id) do
      nil -> nil
      %Subscription{account_id: existing_account_id} -> existing_account_id
    end
  end

  defp persist_subscription(attrs) do
    case BillingRepository.upsert_subscription(attrs) do
      {:ok, _subscription} -> :ok
      {:error, reason} -> {:error, reason}
    end
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
        |> Subscription.changeset(%{status: :past_due})
        |> MetricFlow.Repo.update()
        |> case do
          {:ok, updated} ->
            notify_payment_failed(updated.account_id)
            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp notify_payment_failed(account_id) do
    with %Account{originator_user_id: user_id} <- MetricFlow.Repo.get(Account, account_id),
         %{email: email} <- user_id && Users.get_user!(user_id) do
      BillingNotifier.deliver_payment_failed(email)
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
  @spec create_checkout_session(integer(), map(), String.t()) ::
          {:ok, String.t()} | {:error, term()}
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

    case StripeClient.create_checkout_session(plan, return_url,
           stripe_account: stripe_account,
           account_id: account_id
         ) do
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
            |> Subscription.changeset(%{
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
  Create an agency subscription plan, provisioning a Stripe Product and
  Price on the agency's connected Stripe account first so a plan is never
  persisted without a usable `stripe_price_id`.
  """
  @spec create_plan(map()) :: {:ok, MetricFlow.Billing.Plan.t()} | {:error, term()}
  def create_plan(attrs) do
    alias MetricFlow.Billing.{Plan, StripeClient}

    changeset = Plan.changeset(%Plan{}, attrs)

    if changeset.valid? do
      with {:ok, stripe_price_id} <- provision_stripe_price(changeset) do
        changeset
        |> Ecto.Changeset.put_change(:stripe_price_id, stripe_price_id)
        |> MetricFlow.Repo.insert()
      end
    else
      {:error, %{changeset | action: :insert}}
    end
  end

  defp provision_stripe_price(changeset) do
    alias MetricFlow.Billing.StripeClient

    name = Ecto.Changeset.get_field(changeset, :name)
    price_cents = Ecto.Changeset.get_field(changeset, :price_cents)
    currency = Ecto.Changeset.get_field(changeset, :currency)
    billing_interval = Ecto.Changeset.get_field(changeset, :billing_interval)
    agency_account_id = Ecto.Changeset.get_field(changeset, :agency_account_id)

    case agency_account_id && BillingRepository.get_stripe_account_by_agency(agency_account_id) do
      %{stripe_account_id: stripe_account_id} ->
        with {:ok, product} <-
               StripeClient.create_product(name, stripe_account: stripe_account_id),
             {:ok, price} <-
               StripeClient.create_price(product["id"], price_cents,
                 currency: currency,
                 interval: to_string(billing_interval),
                 stripe_account: stripe_account_id
               ) do
          {:ok, price["id"]}
        end

      _ ->
        {:error, :stripe_account_not_connected}
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
