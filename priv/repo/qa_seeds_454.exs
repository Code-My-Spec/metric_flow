# priv/repo/qa_seeds_454.exs
#
# Story 454: Client Views White-labeled Interface
# Seeds agency account with white-label config and originator grant.
# Idempotent — safe to run multiple times.
#
# Run AFTER priv/repo/qa_seeds.exs:
#   mix run priv/repo/qa_seeds.exs
#   mix run priv/repo/qa_seeds_454.exs
#
# Creates:
#   - "QA Agency 454"       — team account acting as the agency
#   - WhiteLabelConfig      — subdomain: qa454brand, logo, colors #FF5733 / #33FF57
#   - AgencyClientAccessGrant — agency -> "QA Test Account" (originator, admin)

import Ecto.Query

alias MetricFlow.Accounts.{Account, AccountMember}
alias MetricFlow.Agencies
alias MetricFlow.Agencies.{AgencyClientAccessGrant, WhiteLabelConfig}
alias MetricFlow.Repo
alias MetricFlow.Users
alias MetricFlow.Users.Scope

IO.puts("\n--- Story 454 Seeds: White-Label Branding ---")

# ---------------------------------------------------------------------------
# Load the QA owner user
# ---------------------------------------------------------------------------

qa_user =
  case Users.get_user_by_email("qa@example.com") do
    nil ->
      raise "qa@example.com not found — run mix run priv/repo/qa_seeds.exs first"

    user ->
      IO.puts("  Found owner user: #{user.email} (id=#{user.id})")
      user
  end

scope = Scope.for_user(qa_user)

# ---------------------------------------------------------------------------
# Find the QA Test Account (client account)
# ---------------------------------------------------------------------------

client_account =
  Repo.one(
    from a in Account,
      join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^qa_user.id,
      where: a.name == "QA Test Account",
      limit: 1
  ) ||
    raise "QA Test Account not found for qa@example.com — run mix run priv/repo/qa_seeds.exs first"

IO.puts(~s[  Client account: "#{client_account.name}" (id=#{client_account.id})])

# ---------------------------------------------------------------------------
# Find or create the agency account "QA Agency 454"
# ---------------------------------------------------------------------------

IO.puts("\n--- Agency Account ---")

agency_account =
  case Repo.get_by(Account, name: "QA Agency 454") do
    nil ->
      unique = :erlang.unique_integer([:positive])

      account =
        %Account{}
        |> Account.creation_changeset(%{
          name: "QA Agency 454",
          slug: "qa-agency-454-#{unique}",
          type: "team",
          originator_user_id: qa_user.id
        })
        |> Repo.insert!()

      IO.puts(~s[  Created: "QA Agency 454" (id=#{account.id})])
      account

    existing ->
      IO.puts(~s[  Exists: "QA Agency 454" (id=#{existing.id})])
      existing
  end

# ---------------------------------------------------------------------------
# Upsert white-label config for the agency
# ---------------------------------------------------------------------------

IO.puts("\n--- White-Label Config ---")

existing_wl =
  Repo.get_by(WhiteLabelConfig, agency_id: agency_account.id)

_white_label_config =
  case existing_wl do
    nil ->
      %WhiteLabelConfig{}
      |> WhiteLabelConfig.changeset(%{
        agency_id: agency_account.id,
        subdomain: "qa454brand",
        logo_url: "https://example.com/qa454-logo.png",
        primary_color: "#FF5733",
        secondary_color: "#33FF57"
      })
      |> Repo.insert!()
      |> tap(fn c -> IO.puts("  Created white-label config (id=#{c.id}, subdomain=#{c.subdomain})") end)

    existing ->
      IO.puts("  Exists: white-label config (id=#{existing.id}, subdomain=#{existing.subdomain})")
      existing
  end

# ---------------------------------------------------------------------------
# Grant originator access: agency -> client account
# ---------------------------------------------------------------------------

IO.puts("\n--- Agency Client Access Grant ---")

existing_grant =
  Repo.get_by(AgencyClientAccessGrant,
    agency_account_id: agency_account.id,
    client_account_id: client_account.id
  )

_grant =
  case existing_grant do
    nil ->
      # Use direct Repo insert to avoid the authorize check (qa_user owns agency_account
      # but the scope check requires an AccountMember record — the owner membership
      # is created by create_team_account, so grant_client_account_access should work)
      case Agencies.grant_client_account_access(
             scope,
             agency_account.id,
             client_account.id,
             :admin,
             true
           ) do
        {:ok, grant} ->
          IO.puts(~s[  Granted originator/admin: "QA Agency 454" -> "QA Test Account" (grant id=#{grant.id})])
          grant

        {:error, :unauthorized} ->
          # Fallback: insert directly if scope doesn't include agency membership yet
          grant =
            %AgencyClientAccessGrant{}
            |> AgencyClientAccessGrant.changeset(%{
              agency_account_id: agency_account.id,
              client_account_id: client_account.id,
              access_level: :admin,
              origination_status: :originator
            })
            |> Repo.insert!()

          IO.puts(~s[  Granted (direct insert) originator/admin: "QA Agency 454" -> "QA Test Account" (grant id=#{grant.id})])
          grant

        {:error, reason} ->
          raise "Failed to grant access: #{inspect(reason)}"
      end

    existing ->
      IO.puts("  Exists: grant (id=#{existing.id}, access_level=#{existing.access_level}, origination=#{existing.origination_status})")
      existing
  end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

==========================================
 Story 454 Seeds — White-Label Branding
==========================================

Login:          qa@example.com / hello world!
Agency account: "QA Agency 454" (id=#{agency_account.id})
Client account: "QA Test Account" (id=#{client_account.id})

White-label config:
  Subdomain:       qa454brand
  Logo URL:        https://example.com/qa454-logo.png
  Primary color:   #FF5733
  Secondary color: #33FF57

Agency -> Client: originator access (admin)

Settings page: http://localhost:4070/accounts/settings
Dashboard:     http://localhost:4070/dashboard
==========================================
""")
