# priv/repo/qa_seeds.exs
#
# Creates a complete QA test dataset for MetricFlow.
# Idempotent — safe to run multiple times.
#
# Usage: mix run priv/repo/qa_seeds.exs
#
# Creates:
#   - QA owner user: qa@example.com / hello world!
#   - QA member user: qa-member@example.com / hello world!
#   - Team account "QA Test Account" (qa@example.com is owner)
#   - Both users confirmed and able to log in with password

alias MetricFlow.{Accounts, Repo, Users}
alias MetricFlow.Users.{Scope, UserToken}

# ---------------------------------------------------------------------------
# Helper: find or create a confirmed user
# ---------------------------------------------------------------------------

defmodule QaSeed do
  def find_or_create_user(email, password, account_name) do
    case Users.get_user_by_email(email) do
      nil ->
        {:ok, user} =
          Users.register_user(%{
            email: email,
            password: password,
            account_name: account_name
          })

        # Confirm the user via magic link token so they can log in with password
        {token, user_token} = UserToken.build_email_token(user, "login")
        Repo.insert!(user_token)

        {:ok, {confirmed_user, _expired}} = Users.login_user_by_magic_link(token)

        # Set the password after confirmation (magic link login clears all tokens)
        {:ok, {user_with_password, _}} =
          Users.update_user_password(confirmed_user, %{password: password})

        IO.puts("  Created and confirmed: #{email}")
        user_with_password

      existing ->
        IO.puts("  Exists: #{email} (confirmed_at=#{existing.confirmed_at})")
        existing
    end
  end
end

# ---------------------------------------------------------------------------
# 1. QA Users
# ---------------------------------------------------------------------------

IO.puts("\n--- QA Owner User ---")
qa_user = QaSeed.find_or_create_user("qa@example.com", "hello world!", "QA Personal")

IO.puts("\n--- QA Member User ---")
qa_member = QaSeed.find_or_create_user("qa-member@example.com", "hello world!", "Member Personal")

scope = Scope.for_user(qa_user)

# ---------------------------------------------------------------------------
# 2. Team Account
# ---------------------------------------------------------------------------

IO.puts("\n--- Team Account ---")

import Ecto.Query

existing_team_account =
  Repo.one(
    from(a in MetricFlow.Accounts.Account,
      join: m in MetricFlow.Accounts.AccountMember,
      on: m.account_id == a.id and m.user_id == ^qa_user.id,
      where: a.type == "team" and a.name == "QA Test Account",
      limit: 1
    )
  )

_team_account =
  case existing_team_account do
    nil ->
      {:ok, account} =
        Accounts.create_team_account(scope, %{
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
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

==========================================
 QA Seed Data — Credentials
==========================================

Owner:    qa@example.com / hello world!
Member:   qa-member@example.com / hello world!
URL:      http://localhost:4070/users/log-in

Both users are confirmed and can log in with email + password.
Team account "QA Test Account" — qa@example.com is the owner.

Dev mailbox: http://localhost:4070/dev/mailbox
==========================================
""")
