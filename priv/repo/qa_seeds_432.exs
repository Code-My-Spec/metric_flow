# priv/repo/qa_seeds_432.exs
#
# Story 432: User or Agency Self-Revokes Access
# Sets up a team account with a second user accepted as a read_only member.
# Idempotent — safe to run multiple times.
#
# Usage: mix run priv/repo/qa_seeds_432.exs
#
# Creates (in addition to base qa_seeds.exs data):
#   - Ensures qa@example.com owns "QA Test Account"
#   - Adds qa-member@example.com as an accepted read_only member of that account
#     (by creating and accepting an invitation)

alias MetricFlow.{Accounts, Invitations, Repo, Users}
alias MetricFlow.Accounts.{Account, AccountMember}
alias MetricFlow.Users.{Scope, UserToken}

import Ecto.Query

# ---------------------------------------------------------------------------
# Helper: find or create a confirmed user
# ---------------------------------------------------------------------------

defmodule QaSeed432 do
  def find_or_create_user(email, password, account_name) do
    case Users.get_user_by_email(email) do
      nil ->
        {:ok, user} =
          Users.register_user(%{
            email: email,
            password: password,
            account_name: account_name
          })

        {token, user_token} = UserToken.build_email_token(user, "login")
        Repo.insert!(user_token)

        {:ok, {confirmed_user, _expired}} = Users.login_user_by_magic_link(token)

        {:ok, {user_with_password, _}} =
          Users.update_user_password(confirmed_user, %{password: password})

        IO.puts("  Created and confirmed: #{email}")
        user_with_password

      existing ->
        IO.puts("  Exists: #{email}")
        existing
    end
  end
end

# ---------------------------------------------------------------------------
# 1. Ensure both users exist
# ---------------------------------------------------------------------------

IO.puts("\n--- QA Owner User ---")
qa_user = QaSeed432.find_or_create_user("qa@example.com", "hello world!", "QA Personal")

IO.puts("\n--- QA Member User ---")
qa_member = QaSeed432.find_or_create_user("qa-member@example.com", "hello world!", "Member Personal")

owner_scope = Scope.for_user(qa_user)

# ---------------------------------------------------------------------------
# 2. Ensure team account exists
# ---------------------------------------------------------------------------

IO.puts("\n--- Team Account ---")

team_account =
  Repo.one(
    from(a in Account,
      join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^qa_user.id,
      where: a.type == "team" and a.name == "QA Test Account",
      limit: 1
    )
  )

team_account =
  case team_account do
    nil ->
      {:ok, account} =
        Accounts.create_team_account(owner_scope, %{
          name: "QA Test Account",
          slug: "qa-test-account-#{:erlang.unique_integer([:positive])}"
        })

      IO.puts("  Created: QA Test Account (id=#{account.id})")
      account

    existing ->
      IO.puts("  Exists: QA Test Account (id=#{existing.id})")
      existing
  end

# ---------------------------------------------------------------------------
# 3. Ensure qa-member@example.com is an accepted member of the team account
# ---------------------------------------------------------------------------

IO.puts("\n--- Team Account Membership ---")

existing_membership =
  Repo.one(
    from(m in AccountMember,
      where: m.user_id == ^qa_member.id and m.account_id == ^team_account.id,
      limit: 1
    )
  )

case existing_membership do
  nil ->
    # Create and immediately accept an invitation for the member
    {:ok, invitation} =
      Invitations.create_invitation(%{
        email: qa_member.email,
        role: :read_only,
        account_id: team_account.id,
        invited_by_user_id: qa_user.id
      })

    member_scope = Scope.for_user(qa_member)
    {:ok, _membership} = Invitations.accept_invitation(member_scope, invitation.token)

    IO.puts("  Invited and accepted: qa-member@example.com as read_only member")

  existing ->
    IO.puts("  Already a member: qa-member@example.com (role=#{existing.role})")
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

==========================================
 QA Seed Data — Story 432 Credentials
==========================================

Owner:    qa@example.com / hello world!
Member:   qa-member@example.com / hello world!
URL:      http://localhost:4070/users/log-in

Team account "QA Test Account":
  - qa@example.com is the owner
  - qa-member@example.com is a read_only member (accepted)

Dev mailbox: http://localhost:4070/dev/mailbox
==========================================
""")
