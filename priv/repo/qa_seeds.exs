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

team_account =
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
# 2a. Reset membership roles to expected baseline
#
# Roles can drift between QA runs (e.g. a test swaps owner/member roles).
# We always reset qa@example.com to :owner and qa-member@example.com to
# :read_only so each QA run starts from a known state.
# ---------------------------------------------------------------------------

IO.puts("\n--- Reset Membership Roles ---")

# Ensure qa-member@example.com is a member of the team account first
existing_member_membership =
  Repo.one(
    from(m in MetricFlow.Accounts.AccountMember,
      where: m.account_id == ^team_account.id and m.user_id == ^qa_member.id,
      limit: 1
    )
  )

if is_nil(existing_member_membership) do
  Accounts.add_user_to_account(scope, qa_member.id, team_account.id, :read_only)
  IO.puts("  Added qa-member@example.com to QA Test Account as read_only")
end

# Reset qa@example.com to :owner
{owner_count, _} =
  Repo.update_all(
    from(m in MetricFlow.Accounts.AccountMember,
      where: m.account_id == ^team_account.id and m.user_id == ^qa_user.id
    ),
    set: [role: :owner]
  )

IO.puts("  Reset qa@example.com to owner (#{owner_count} row(s) updated)")

# Reset qa-member@example.com to :read_only
{member_count, _} =
  Repo.update_all(
    from(m in MetricFlow.Accounts.AccountMember,
      where: m.account_id == ^team_account.id and m.user_id == ^qa_member.id
    ),
    set: [role: :read_only]
  )

IO.puts("  Reset qa-member@example.com to read_only (#{member_count} row(s) updated)")

# ---------------------------------------------------------------------------
# 2b. Clear sync history and sync jobs for QA user (clean slate for QA runs)
# ---------------------------------------------------------------------------

IO.puts("\n--- Clear Sync History ---")

{sync_history_count, _} =
  Repo.delete_all(
    from(sh in "sync_history",
      join: i in "integrations",
      on: sh.integration_id == i.id,
      where: i.user_id == ^qa_user.id
    )
  )

{sync_jobs_count, _} =
  Repo.delete_all(
    from(sj in "sync_jobs",
      join: i in "integrations",
      on: sj.integration_id == i.id,
      where: i.user_id == ^qa_user.id
    )
  )

IO.puts("  Cleared #{sync_history_count} sync history + #{sync_jobs_count} sync job records for qa@example.com")

# ---------------------------------------------------------------------------
# 3. Google Ads Integration (with selected_accounts for QA Story 436)
# ---------------------------------------------------------------------------

IO.puts("\n--- Google Integrations (separate per service) ---")

alias MetricFlow.Integrations.Integration

google_access_token = System.get_env("GOOGLE_TEST_ACCESS_TOKEN", "qa_test_token")
google_refresh_token = System.get_env("GOOGLE_TEST_REFRESH_TOKEN", "qa_test_refresh")
google_expires_at = DateTime.add(DateTime.utc_now(), 86400, :second)

# Google Analytics integration
unless Repo.get_by(Integration, user_id: qa_user.id, provider: :google_analytics) do
  %Integration{}
  |> Integration.changeset(%{
    user_id: qa_user.id,
    provider: :google_analytics,
    access_token: google_access_token,
    refresh_token: google_refresh_token,
    expires_at: google_expires_at,
    granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "property_id" => System.get_env("GA4_TEST_PROPERTY_ID", "properties/508773792"),
      "selected_accounts" => ["GA4 Property"]
    }
  })
  |> Repo.insert!()

  IO.puts("  Created google_analytics integration")
end

# Google Ads integration
unless Repo.get_by(Integration, user_id: qa_user.id, provider: :google_ads) do
  %Integration{}
  |> Integration.changeset(%{
    user_id: qa_user.id,
    provider: :google_ads,
    access_token: google_access_token,
    refresh_token: google_refresh_token,
    expires_at: google_expires_at,
    granted_scopes: ["https://www.googleapis.com/auth/adwords"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "customer_id" => System.get_env("GOOGLE_ADS_TEST_CUSTOMER_ID", "8952788948"),
      "selected_accounts" => ["Google Ads Account"]
    }
  })
  |> Repo.insert!()

  IO.puts("  Created google_ads integration")
end

# Clean up legacy :google integration if it exists
case Repo.get_by(Integration, user_id: qa_user.id, provider: :google) do
  nil -> :ok
  legacy -> Repo.delete!(legacy); IO.puts("  Removed legacy :google integration")
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
