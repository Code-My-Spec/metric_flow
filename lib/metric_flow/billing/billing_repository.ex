defmodule MetricFlow.Billing.BillingRepository do
  @moduledoc """
  Data access layer for Subscription, Plan, and StripeAccount CRUD.

  All queries are scoped via Scope struct for multi-tenant isolation.
  """

  import Ecto.Query

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Billing.{Plan, ProcessedStripeEvent, StripeAccount, Subscription}
  alias MetricFlow.Repo

  # --- Subscriptions ---

  def get_subscription_by_stripe_id(stripe_subscription_id) do
    Repo.get_by(Subscription, stripe_subscription_id: stripe_subscription_id)
  end

  @doc """
  Fetch a single subscription by its own id, scoped to `agency_account_id`
  via its plan. Used by the cancel action so a forged `phx-value-id` can't
  target another agency's subscription.
  """
  def get_agency_subscription(agency_account_id, subscription_id) do
    Subscription
    |> join(:inner, [s], p in Plan, on: s.plan_id == p.id)
    |> where([s, p], p.agency_account_id == ^agency_account_id and s.id == ^subscription_id)
    |> Repo.one()
  end

  def get_subscription_by_account_id(account_id) do
    now = DateTime.utc_now()

    Subscription
    |> where([s], s.account_id == ^account_id)
    |> where(
      [s],
      s.status != :cancelled or is_nil(s.current_period_end) or s.current_period_end > ^now
    )
    |> preload(:plan)
    |> Repo.one()
  end

  @doc """
  Records a Stripe event ID and type as being processed. An event already
  recorded with status `:processed` is a true redelivery and short-circuits
  as `{:duplicate, event}`; one recorded `:processing` or `:failed` (a prior
  attempt that never completed, or completed unsuccessfully) is reset to
  `:processing` and returned for reprocessing, so a Stripe retry of a failed
  event can actually succeed instead of being locked out forever.
  """
  def mark_event_processed(stripe_event_id, event_type) do
    case Repo.get_by(ProcessedStripeEvent, stripe_event_id: stripe_event_id) do
      nil ->
        insert_processed_event(stripe_event_id, event_type)

      %ProcessedStripeEvent{status: :processed} = event ->
        {:duplicate, event}

      %ProcessedStripeEvent{} = event ->
        event
        |> ProcessedStripeEvent.status_changeset(:processing)
        |> Repo.update()
    end
  end

  defp insert_processed_event(stripe_event_id, event_type) do
    %ProcessedStripeEvent{}
    |> ProcessedStripeEvent.changeset(%{stripe_event_id: stripe_event_id, event_type: event_type})
    |> Repo.insert()
    |> case do
      {:error, %Ecto.Changeset{errors: errors} = changeset} ->
        if Keyword.has_key?(errors, :stripe_event_id) do
          {:duplicate, Repo.get_by(ProcessedStripeEvent, stripe_event_id: stripe_event_id)}
        else
          {:error, changeset}
        end

      ok ->
        ok
    end
  end

  @doc """
  Records the outcome (:processed or :failed) once dispatch has run, so the
  audit row reflects what actually happened rather than just that an event
  arrived.
  """
  def record_event_outcome(%ProcessedStripeEvent{} = event, status) do
    event
    |> ProcessedStripeEvent.status_changeset(status)
    |> Repo.update()
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

  def get_plan_by_stripe_price_id(stripe_price_id) do
    Repo.get_by(Plan, stripe_price_id: stripe_price_id)
  end

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

  def count_past_due_agency_subscriptions(agency_account_id) do
    Subscription
    |> join(:inner, [s], p in Plan, on: s.plan_id == p.id)
    |> where([s, p], p.agency_account_id == ^agency_account_id)
    |> where([s], s.status == :past_due)
    |> Repo.aggregate(:count)
  end

  @doc """
  Flags an agency's active customer subscriptions for review by marking them
  `:past_due`. Called when the agency disconnects its Stripe account, since
  billing through that account can no longer proceed as normal.
  """
  def flag_agency_subscriptions_for_review(agency_account_id) do
    Subscription
    |> join(:inner, [s], p in Plan, on: s.plan_id == p.id)
    |> where([s, p], p.agency_account_id == ^agency_account_id and s.status == :active)
    |> Repo.update_all(set: [status: :past_due])
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

    query
    |> join(:inner, [s, p], a in Account, on: s.account_id == a.id)
    |> where(
      [s, p, a],
      ilike(s.stripe_customer_id, ^search_term) or ilike(a.name, ^search_term)
    )
  end

  # --- Private ---

  defp maybe_filter_agency(query, nil), do: where(query, [p], is_nil(p.agency_account_id))
  defp maybe_filter_agency(query, id), do: where(query, [p], p.agency_account_id == ^id)
end
