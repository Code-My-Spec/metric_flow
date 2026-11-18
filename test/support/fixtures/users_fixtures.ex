defmodule MetricFlowTest.UsersFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MetricFlow.Users` context.
  """

  import Ecto.Query

  alias MetricFlow.Users
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.UserToken

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  def valid_user_password, do: "hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      account_name: "Test Account"
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Users.register_user()

    user
  end

  def user_fixture(attrs \\ %{}) do
    user = unconfirmed_user_fixture(attrs)

    token =
      extract_user_token(fn url ->
        Users.deliver_login_instructions(user, url)
      end)

    {:ok, {user, _expired_tokens}} =
      Users.login_user_by_magic_link(token)

    user
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  @doc """
  The account a user's plain `Scope.for_user/1` acts on (their active /
  originated account) -- the owner of the data account-scoped fixtures
  create for that user. See `MetricFlow.AccountAccess.default_account_id/1`.

  `user_fixture/1` users have no account (registration through the UI is
  what creates one), so when the user has none this creates the account a
  real sign-up would have: a client account they originated and own.
  """
  def default_account_id(%{id: user_id}), do: default_account_id(user_id)

  def default_account_id(user_id) when is_integer(user_id) do
    MetricFlow.AccountAccess.default_account_id(user_id) || originated_account_fixture(user_id).id
  end

  @doc """
  A user with the account a real sign-up creates (a client account they
  originated and own).
  """
  def user_with_account_fixture(attrs \\ %{}) do
    user = user_fixture(attrs)
    default_account_id(user)
    user
  end

  @doc "Creates a client account originated and owned by the user."
  def originated_account_fixture(user_id) when is_integer(user_id) do
    unique = System.unique_integer([:positive])

    account =
      %MetricFlow.Accounts.Account{}
      |> MetricFlow.Accounts.Account.creation_changeset(%{
        name: "Personal Account #{unique}",
        slug: "personal-account-#{unique}",
        type: "client",
        originator_user_id: user_id
      })
      |> MetricFlow.Repo.insert!()

    %MetricFlow.Accounts.AccountMember{}
    |> MetricFlow.Accounts.AccountMember.changeset(%{
      account_id: account.id,
      user_id: user_id,
      role: :owner
    })
    |> MetricFlow.Repo.insert!()

    account
  end

  @doc """
  A scope for the user acting in their default account (creating it when
  the user has none), the way the web layer's active-account hook scopes
  every request.
  """
  def account_scope_fixture(user) do
    Scope.put_account_id(Scope.for_user(user), default_account_id(user))
  end

  @doc "PubSub topic carrying sync events for the user's default account."
  def sync_topic_for(user), do: MetricFlow.AccountAccess.sync_topic(default_account_id(user))

  @doc "PubSub topic carrying correlation updates for the user's default account."
  def correlations_topic_for(user),
    do: MetricFlow.AccountAccess.correlations_topic(default_account_id(user))

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Users.update_user_password(user, %{password: valid_user_password()})

    user
  end

  @doc """
  Looks up a user by email address. Returns nil if not found.
  Useful in BDD spex after registration via the UI form.
  """
  def get_user_by_email(email) do
    Users.get_user_by_email(email)
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    MetricFlow.Repo.update_all(
      from(t in UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    MetricFlow.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    MetricFlow.Repo.update_all(
      from(ut in UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
