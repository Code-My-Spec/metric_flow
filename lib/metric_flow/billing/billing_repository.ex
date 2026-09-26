defmodule MetricFlow.Billing.BillingRepository do
  @moduledoc """
  Data access layer for Subscription, Plan, and StripeAccount CRUD.

  All queries are scoped via Scope struct for multi-tenant isolation.
  """

  import Ecto.Query

  alias MetricFlow.Billing.{Plan, StripeAccount, Subscription}
  alias MetricFlow.Repo

  # --- Subscriptions ---

  def get_subscription_by_stripe_id(stripe_subscription_id) do
    Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription_id)
  end

  def get_subscription_by_account_id(account_id) do
    Repo.get_by(Subscription, account_id: account_id)
  end

  def upsert_subscription(attrs) do
    stripe_id = attrs[:stripe_subscription_id] || attrs["stripe_subscription_id"]

    case stripe_id && get_subscription_by_stripe_id(stripe_id) do
      nil ->
        %Subscription{}
        |> Subscription.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> Subscription.changeset(attrs)
        |> Repo.update()
    end
  end

  # --- Plans ---

  @doc """
  The plans a customer may choose from — active only.
  """
  def list_plans(agency_account_id \\ nil) do
    agency_account_id
    |> plans_query()
    |> where([p], p.active == true)
    |> Repo.all()
  end

  @doc """
  Every plan an agency has ever made, active or not.

  The management screen is the one place a deactivated plan still has to be
  visible: it renders an Active/Inactive badge per row, and deactivating one is
  meant to mark it rather than remove it. Served by its own function instead of
  an option on `list_plans/1`, because the other caller is
  `SubscriptionLive.Checkout` — a customer choosing what to pay for, which must
  never be offered a plan that was withdrawn.
  """
  def list_all_plans(agency_account_id \\ nil) do
    agency_account_id
    |> plans_query()
    |> Repo.all()
  end

  defp plans_query(agency_account_id) do
    Plan
    |> maybe_filter_agency(agency_account_id)
    |> order_by([p], asc: p.price_cents)
  end

  def get_plan(id), do: Repo.get(Plan, id)

  def create_plan(attrs) do
    %Plan{}
    |> Plan.changeset(attrs)
    |> Repo.insert()
  end

  # --- Stripe Accounts ---

  def get_stripe_account_by_agency(agency_account_id) do
    Repo.get_by(StripeAccount, agency_account_id: agency_account_id)
  end

  def get_stripe_account_by_stripe_id(stripe_account_id) do
    Repo.get_by(StripeAccount, stripe_account_id: stripe_account_id)
  end

  def upsert_stripe_account(attrs) do
    agency_id = attrs[:agency_account_id] || attrs["agency_account_id"]

    case agency_id && get_stripe_account_by_agency(agency_id) do
      nil ->
        %StripeAccount{}
        |> StripeAccount.changeset(attrs)
        |> Repo.insert()

      existing ->
        existing
        |> StripeAccount.changeset(attrs)
        |> Repo.update()
    end
  end

  # --- Agency Subscriptions ---

  def list_agency_subscriptions(agency_account_id, opts \\ []) do
    search = Keyword.get(opts, :search)
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    Subscription
    |> join(:inner, [s], p in Plan, on: s.plan_id == p.id)
    |> where([s, p], p.agency_account_id == ^agency_account_id)
    |> maybe_search(search)
    |> order_by([s], desc: s.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> preload(:plan)
    |> Repo.all()
  end

  def count_active_agency_subscriptions(agency_account_id) do
    Subscription
    |> join(:inner, [s], p in Plan, on: s.plan_id == p.id)
    |> where([s, p], p.agency_account_id == ^agency_account_id)
    |> where([s], s.status == :active)
    |> Repo.aggregate(:count)
  end

  def calculate_mrr(agency_account_id) do
    Subscription
    |> join(:inner, [s], p in Plan, on: s.plan_id == p.id)
    |> where([s, p], p.agency_account_id == ^agency_account_id)
    |> where([s], s.status == :active)
    |> select([s, p], sum(p.price_cents))
    |> Repo.one()
    |> Kernel.||(0)
  end

  defp maybe_search(query, nil), do: query
  defp maybe_search(query, ""), do: query

  defp maybe_search(query, search) do
    search_term = "%#{search}%"
    where(query, [s], ilike(s.stripe_customer_id, ^search_term))
  end

  # --- Private ---

  defp maybe_filter_agency(query, nil), do: where(query, [p], is_nil(p.agency_account_id))
  defp maybe_filter_agency(query, id), do: where(query, [p], p.agency_account_id == ^id)
end
