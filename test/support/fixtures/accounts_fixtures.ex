defmodule MetricFlowTest.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MetricFlow.Accounts` context.
  """

  alias MetricFlow.Accounts.{Account, Member}
  alias MetricFlow.Repo

  def valid_account_attributes(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Test Account #{unique_id}",
      slug: "test-account-#{unique_id}",
      type: :team
    })
  end

  def valid_personal_account_attributes(attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      name: "Personal Account #{unique_id}",
      slug: "personal-#{unique_id}",
      type: :personal
    })
  end

  def account_fixture(attrs \\ %{}) do
    Account.create_changeset(valid_account_attributes(attrs))
    |> Repo.insert!()
  end

  def personal_account_fixture(attrs \\ %{}) do
    Account.create_changeset(valid_personal_account_attributes(attrs))
    |> Repo.insert!()
  end

  def valid_member_attributes(user, account, attrs \\ %{}) do
    Enum.into(attrs, %{
      user_id: user.id,
      account_id: account.id,
      role: :member
    })
  end

  def member_fixture(user, account, role \\ :member) do
    %Member{}
    |> Member.changeset(valid_member_attributes(user, account, %{role: role}))
    |> Repo.insert!()
  end

  def account_with_owner_fixture(user, attrs \\ %{}) do
    account = account_fixture(attrs)
    _member = member_fixture(user, account, :owner)
    account
  end

  def personal_account_with_owner_fixture(user, attrs \\ %{}) do
    account = personal_account_fixture(attrs)
    _member = member_fixture(user, account, :owner)
    account
  end
end
