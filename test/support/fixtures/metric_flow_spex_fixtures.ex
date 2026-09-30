defmodule MetricFlowSpex.Fixtures do
  @moduledoc """
  The one seam through which a spex may reach application state.

  Its own top-level boundary rather than a member of `MetricFlowSpex`, and that
  is the whole point: the bridge needs wide deps to re-export anything useful,
  and if it sat inside the spex boundary those deps would be in scope for every
  `_spex.exs` file too, which defeats the seal. Wide deps here, narrow public
  surface out.

  **Keep it narrow.** Every function added is a permanent surface that spex
  depend on, and the equivalent bridge on CodeMySpec grew into something slated
  for trimming. Before adding one, check whether the spex can assert off the
  *surface* instead — a `then_` that reads the database is asserting against
  the writer rather than against what the user sees. Using an existing function
  is fine; adding one needs a real reason, said out loud.

  The 374 spex here drove everything through the Web layer with no bridge
  until now. Story 1099's webhook-correlation specs need to know which
  account a given user's webhook events belong to before firing the
  webhook — no UI surfaces an account id, so that lookup is the first
  function here.
  """
  use Boundary, top_level?: true, deps: [MetricFlow, MetricFlowTest]

  import Ecto.Query

  alias MetricFlow.Accounts
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Agencies
  alias MetricFlow.Billing.BillingRepository
  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Repo
  alias MetricFlow.Users
  alias MetricFlow.Users.Scope

  @doc """
  The personal account id for the user registered with `email`.

  For specs that need an account id to correlate a webhook or API payload
  with the account it should affect, without reading the DB directly.
  """
  @spec personal_account_id(String.t()) :: integer()
  def personal_account_id(email) do
    scope_for(email) |> Accounts.get_personal_account_id()
  end

  @doc """
  The name of the personal account for the user registered with `email`.
  """
  @spec personal_account_name(String.t()) :: String.t()
  def personal_account_name(email) do
    [account | _] = scope_for(email) |> Accounts.list_accounts()
    account.name
  end

  @doc """
  The slug of the personal account for the user registered with `email`.

  For specs that grant agency access by slug, the only identifier the
  "Agency Access" grant form accepts.
  """
  @spec personal_account_slug(String.t()) :: String.t()
  def personal_account_slug(email) do
    scope = scope_for(email)
    account_id = Accounts.get_personal_account_id(scope)
    account = Accounts.get_account!(scope, account_id)
    account.slug
  end

  @doc """
  Grants a client account access to the agency owned by `email`, as the
  agency's own scope would. No UI exists yet for creating and granting
  client account access, so specs need this to set up an agency's client
  accounts before exercising the surface under test.
  """
  @spec grant_client_account_access(String.t(), integer(), atom(), boolean()) :: :ok
  def grant_client_account_access(email, client_account_id, access_level, is_originator) do
    scope = scope_for(email)
    agency_account_id = Accounts.get_personal_account_id(scope)

    {:ok, _grant} =
      Agencies.grant_client_account_access(
        scope,
        agency_account_id,
        client_account_id,
        access_level,
        is_originator
      )

    :ok
  end

  @doc """
  The account that `email`'s user originated, for specs asserting on
  white-label branding inherited from the originating agency.
  """
  @spec account_originated_by(String.t()) :: Account.t()
  def account_originated_by(email) do
    user = Users.get_user_by_email(email)
    Repo.get_by!(Account, originator_user_id: user.id)
  end

  @doc """
  Creates a built-in canned dashboard owned by `email`'s user, for specs
  asserting on system-provided dashboard templates. There is no UI for
  seeding built-in dashboards.
  """
  @spec create_canned_dashboard!(String.t(), String.t()) :: :ok
  def create_canned_dashboard!(email, name) do
    user = Users.get_user_by_email(email)

    Repo.insert!(%MetricFlow.Dashboards.Dashboard{
      name: name,
      description: "System-provided #{name} dashboard",
      built_in: true,
      user_id: user.id
    })

    :ok
  end

  @doc """
  Backdates the invitation identified by `token` so it reads as expired.
  There is no UI path to expire an invitation, so specs asserting on
  expiry behavior need to move the clock this way instead.
  """
  @spec expire_invitation!(String.t()) :: :ok
  def expire_invitation!(token) do
    token_hash = Invitation.token_hash(token)

    Repo.update_all(
      from(i in Invitation, where: i.token_hash == ^token_hash),
      set: [inserted_at: ~N[2000-01-01 00:00:00]]
    )

    :ok
  end

  @doc """
  Delivers a fresh login-instructions email to `email`'s user and returns
  the token, for specs that need a real magic-link token without a UI
  path that issues one directly (e.g. re-verifying after registration).
  """
  @spec login_token_for(String.t()) :: String.t()
  def login_token_for(email) do
    user = Users.get_user_by_email(email)
    {:ok, captured_email} = Users.deliver_login_instructions(user, &("[TOKEN]" <> &1 <> "[TOKEN]"))
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  @doc """
  Creates an active subscription for a fresh client account against
  `plan`, originated by the user registered with `owner_email`. For
  specs asserting on agency-side effects of an existing customer
  subscription (e.g. disconnecting the agency's Stripe account flagging
  it for review). No UI path creates a subscription tied to a specific
  plan_id — the webhook handler that creates Subscription rows from
  Stripe events never threads plan_id through at all.
  """
  @spec agency_customer_subscription!(String.t(), MetricFlow.Billing.Plan.t()) ::
          MetricFlow.Billing.Subscription.t()
  def agency_customer_subscription!(owner_email, plan) do
    user = Users.get_user_by_email(owner_email)

    customer_account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "Customer #{System.unique_integer([:positive])}",
        slug: "customer-#{System.unique_integer([:positive])}",
        type: "client",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    Repo.insert!(%MetricFlow.Billing.Subscription{
      stripe_subscription_id: "sub_test_#{System.unique_integer([:positive])}",
      stripe_customer_id: "cus_test_#{System.unique_integer([:positive])}",
      status: :active,
      account_id: customer_account.id,
      plan_id: plan.id,
      current_period_start: DateTime.utc_now() |> DateTime.truncate(:second),
      current_period_end: DateTime.utc_now() |> DateTime.add(30, :day) |> DateTime.truncate(:second)
    })
  end

  @doc """
  The current `status` of `subscription`, for specs asserting on
  agency-side effects (e.g. disconnecting Stripe) that should change a
  customer subscription's state. No UI surfaces subscription status
  directly.
  """
  @spec subscription_status!(integer()) :: atom()
  def subscription_status!(subscription_id) do
    Repo.get!(MetricFlow.Billing.Subscription, subscription_id).status
  end

  @doc """
  The `name` of the customer account that owns `subscription`, for specs
  asserting on search-by-name behavior. No UI surfaces this name today —
  the dashboard's customer list and search both key on `stripe_customer_id`.
  """
  @spec agency_customer_account_name!(MetricFlow.Billing.Subscription.t()) :: String.t()
  def agency_customer_account_name!(subscription) do
    Repo.get!(Account, subscription.account_id).name
  end

  @doc """
  The Stripe Connect account id for the agency owned by `email`, for specs
  that need to tag a webhook payload with the agency's own connected
  account id. No UI surfaces the raw Stripe account id.
  """
  @spec agency_stripe_account_id(String.t()) :: String.t()
  def agency_stripe_account_id(email) do
    account_id = personal_account_id(email)
    %{stripe_account_id: id} = BillingRepository.get_stripe_account_by_agency(account_id)
    id
  end

  defp scope_for(email) do
    email |> Users.get_user_by_email() |> Scope.for_user()
  end
end
