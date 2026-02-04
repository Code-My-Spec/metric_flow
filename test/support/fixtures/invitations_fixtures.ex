defmodule MetricFlowTest.InvitationsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MetricFlow.Invitations` context.
  """

  import MetricFlowTest.AccountsFixtures
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Invitations.Invitation
  alias MetricFlow.Infrastructure.Repo

  def valid_invitation_attributes(account, inviter, attrs \\ %{}) do
    unique_id = System.unique_integer([:positive])

    Enum.into(attrs, %{
      email: "invitee#{unique_id}@example.com",
      role: :member,
      account_id: account.id,
      invited_by_id: inviter.id
    })
  end

  def invitation_fixture(account \\ nil, inviter \\ nil, attrs \\ %{}) do
    inviter = inviter || user_fixture()
    account = account || account_with_owner_fixture(inviter)

    %Invitation{}
    |> Invitation.changeset(valid_invitation_attributes(account, inviter, attrs))
    |> Repo.insert!()
  end

  def pending_invitation_fixture(account \\ nil, inviter \\ nil, attrs \\ %{}) do
    invitation_fixture(account, inviter, attrs)
  end

  def accepted_invitation_fixture(account \\ nil, inviter \\ nil, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    invitation_fixture(account, inviter, Map.put(attrs, :accepted_at, now))
  end

  def expired_invitation_fixture(account \\ nil, inviter \\ nil, attrs \\ %{}) do
    past_date = DateTime.utc_now() |> DateTime.add(-1, :day) |> DateTime.truncate(:second)

    invitation_fixture(
      account,
      inviter,
      Map.merge(attrs, %{
        expires_at: past_date
      })
    )
  end

  def cancelled_invitation_fixture(account \\ nil, inviter \\ nil, attrs \\ %{}) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    invitation_fixture(account, inviter, Map.put(attrs, :cancelled_at, now))
  end
end
