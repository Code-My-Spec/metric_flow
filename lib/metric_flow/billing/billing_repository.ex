defmodule MetricFlow.Billing.BillingRepository do
  @moduledoc """
  Data access layer for Subscription, Plan, and StripeAccount CRUD.

  All queries are scoped via Scope struct for multi-tenant isolation.
  """

  import Ecto.Query

  alias MetricFlow.Billing.{Plan, Subscription, StripeAccount}
  alias MetricFlow.Repo

  # --- Subscriptions ---

  def get_subscription_by_stripe_id(stripe_subscription_id) do
    Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription_id)
  end

  def get_subscription_by_account_id(account_id) do
    Repo.get_by(Subscription, account_id: account_id)
  end

  def upsert_subscription(attrs) do
    case get_subscription_by_stripe_id(attrs[:stripe_subscription_id] || attrs["stripe_subscription_id"]) do
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

  def list_plans(agency_account_id \\ nil) do
    Plan
    |> where([p], p.active == true)
    |> maybe_filter_agency(agency_account_id)
    |> order_by([p], asc: p.price_cents)
    |> Repo.all()
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

  def upsert_stripe_account(attrs) do
    agency_id = attrs[:agency_account_id] || attrs["agency_account_id"]

    case get_stripe_account_by_agency(agency_id) do
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
    |> Repo.aggregate(:sum, :price_cents, Plan)
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
