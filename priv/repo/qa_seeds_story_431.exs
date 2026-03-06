# priv/repo/qa_seeds_story_431.exs
#
# Story 431: Agency Views and Manages Client Accounts
# Seeds agency/client account relationships for browser-based QA.
# Idempotent — safe to run multiple times.
#
# Run AFTER priv/repo/qa_seeds.exs:
#   mix run priv/repo/qa_seeds.exs
#   mix run priv/repo/qa_seeds_story_431.exs
#
# Creates:
#   - qa@example.com's team account (QA Test Account) acts as the agency
#   - "Client Alpha"           — admin access, is_originator: true  → Originator badge
#   - "Client Beta"            — admin access, is_originator: false → Invited badge
#   - "Client Read Only"       — read_only access, is_originator: false
#   - "Client Account Manager" — account_manager access, is_originator: false

import Ecto.Query

alias MetricFlow.{Accounts, Agencies, Repo, Users}
alias MetricFlow.Accounts.{Account, AccountMember}
alias MetricFlow.Agencies.AgencyClientAccessGrant
alias MetricFlow.Users.Scope

IO.puts("\n--- Story 431 Seeds: Agency Client Accounts ---")

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
# Find the agency account by name (QA Test Account)
# Look up directly by name rather than relying on list order, since
# grant propagation adds the owner as a member of client accounts too.
# ---------------------------------------------------------------------------

agency_account =
  Repo.one(
    from a in Account,
      join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^qa_user.id,
      where: a.name == "QA Test Account",
      limit: 1
  ) ||
    raise "QA Test Account not found for qa@example.com — run mix run priv/repo/qa_seeds.exs first"

IO.puts("  Agency account: \"#{agency_account.name}\" (id=#{agency_account.id})")

# ---------------------------------------------------------------------------
# Helper: find or create a client account
# Uses qa_user as originator_user_id to satisfy the FK without creating extra users.
# ---------------------------------------------------------------------------

defmodule Story431Seed do
  alias MetricFlow.Accounts.Account
  alias MetricFlow.Repo

  def find_or_create_client(name, originator_user_id) do
    case Repo.get_by(Account, name: name) do
      nil ->
        unique = :erlang.unique_integer([:positive])

        account =
          %Account{}
          |> Account.creation_changeset(%{
            name: name,
            slug: "qa431-client-#{unique}",
            type: "team",
            originator_user_id: originator_user_id
          })
          |> Repo.insert!()

        IO.puts("  Created client account: \"#{name}\" (id=#{account.id})")
        account

      existing ->
        IO.puts("  Exists: \"#{name}\" (id=#{existing.id})")
        existing
    end
  end
end

client_alpha = Story431Seed.find_or_create_client("Client Alpha", qa_user.id)
client_beta = Story431Seed.find_or_create_client("Client Beta", qa_user.id)
client_read_only = Story431Seed.find_or_create_client("Client Read Only", qa_user.id)
client_account_manager = Story431Seed.find_or_create_client("Client Account Manager", qa_user.id)

# ---------------------------------------------------------------------------
# Helper: grant access if not already granted
# ---------------------------------------------------------------------------

defmodule Story431Grant do
  alias MetricFlow.Agencies.AgencyClientAccessGrant
  alias MetricFlow.Repo

  def grant_if_absent(scope, agency_id, client_account, access_level, is_originator) do
    client_id = client_account.id

    case Repo.get_by(AgencyClientAccessGrant,
           agency_account_id: agency_id,
           client_account_id: client_id
         ) do
      nil ->
        {:ok, _grant} =
          MetricFlow.Agencies.grant_client_account_access(
            scope,
            agency_id,
            client_id,
            access_level,
            is_originator
          )

        badge = if is_originator, do: "Originator", else: "Invited"
        IO.puts("  Granted #{access_level} (#{badge}): \"#{client_account.name}\"")

      existing ->
        IO.puts("  Grant exists: \"#{client_account.name}\" (#{existing.access_level})")
    end
  end
end

Story431Grant.grant_if_absent(scope, agency_account.id, client_alpha, :admin, true)
Story431Grant.grant_if_absent(scope, agency_account.id, client_beta, :admin, false)
Story431Grant.grant_if_absent(scope, agency_account.id, client_read_only, :read_only, false)
Story431Grant.grant_if_absent(scope, agency_account.id, client_account_manager, :account_manager, false)

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

==========================================
 Story 431 Seeds — Agency Client Accounts
==========================================

Agency user:    qa@example.com / hello world!
Agency account: "#{agency_account.name}" (id=#{agency_account.id})

Client accounts accessible to the agency:
  "Client Alpha"           — admin, Originator badge
  "Client Beta"            — admin, Invited badge
  "Client Read Only"       — read_only, Invited badge
  "Client Account Manager" — account_manager, Invited badge

Accounts page: http://localhost:4070/accounts
==========================================
""")
