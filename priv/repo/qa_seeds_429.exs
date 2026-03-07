# priv/repo/qa_seeds_429.exs
#
# Story 429 — Agency or User Accepts Client Invitation
#
# Creates a pending invitation from the QA owner account to the QA member user,
# plus an already-accepted invitation (to test the "already used" error path).
#
# Usage: mix run priv/repo/qa_seeds_429.exs
#
# Prerequisites: run priv/repo/qa_seeds.exs first.
#
# Creates:
#   - A pending invitation from qa@example.com's "QA Test Account" to qa-member@example.com
#     as an :account_manager (valid, ready to accept)
#   - An already-accepted invitation from the same account (to test the "already used" path)
#
# Prints the encoded invitation token so the tester can build the URL.

alias MetricFlow.Accounts.{Account, AccountMember}
alias MetricFlow.Invitations
alias MetricFlow.Invitations.Invitation
alias MetricFlow.Repo
alias MetricFlow.Users

import Ecto.Query

# ---------------------------------------------------------------------------
# Look up seed users
# ---------------------------------------------------------------------------

IO.puts("\n--- Story 429 Seed: Invitation Tokens ---")

owner = Users.get_user_by_email("qa@example.com")
member = Users.get_user_by_email("qa-member@example.com")

unless owner, do: raise("qa@example.com not found — run qa_seeds.exs first")
unless member, do: raise("qa-member@example.com not found — run qa_seeds.exs first")

# ---------------------------------------------------------------------------
# Find the QA owner's account (any account where they are owner)
# ---------------------------------------------------------------------------

owner_account =
  Repo.one(
    from(a in Account,
      join: m in AccountMember,
      on: m.account_id == a.id and m.user_id == ^owner.id and m.role == :owner,
      limit: 1
    )
  )

unless owner_account, do: raise("No owner account found for qa@example.com — run qa_seeds.exs first")

IO.puts("  Owner account: #{owner_account.name} (id=#{owner_account.id})")

# ---------------------------------------------------------------------------
# Ensure the member is NOT already a member of this account
# (to avoid constraint errors when creating a pending invitation)
# ---------------------------------------------------------------------------

already_member =
  Repo.exists?(
    from(m in AccountMember,
      where: m.user_id == ^member.id and m.account_id == ^owner_account.id
    )
  )

if already_member do
  IO.puts("  NOTE: qa-member is already a member of #{owner_account.name}.")
  IO.puts("  The pending invitation will be created, but accepting it will return :already_member.")
end

# ---------------------------------------------------------------------------
# 1. Pending invitation (ready to accept)
# ---------------------------------------------------------------------------

IO.puts("\n--- Pending Invitation ---")

# Delete any existing pending invitation for this member to ensure a fresh token
existing_pending =
  Repo.one(
    from(i in Invitation,
      where:
        i.account_id == ^owner_account.id and
          i.email == "qa-member@example.com" and
          i.status == :pending,
      limit: 1
    )
  )

_deleted =
  case existing_pending do
    nil -> nil
    inv -> Repo.delete!(inv)
  end

{:ok, pending_invitation} =
  Invitations.create_invitation(%{
    email: "qa-member@example.com",
    role: :account_manager,
    account_id: owner_account.id,
    invited_by_user_id: owner.id
  })

pending_token = pending_invitation.token
IO.puts("  Created pending invitation (id=#{pending_invitation.id})")

# ---------------------------------------------------------------------------
# 2. Already-accepted invitation (for the "already used" error path)
# ---------------------------------------------------------------------------

IO.puts("\n--- Already-Accepted Invitation ---")

{:ok, accepted_invitation} =
  Invitations.create_invitation(%{
    email: "qa-member@example.com",
    role: :account_manager,
    account_id: owner_account.id,
    invited_by_user_id: owner.id
  })

# Mark it accepted immediately so it shows as "already used"
Repo.update!(Invitation.accept_changeset(Repo.get!(Invitation, accepted_invitation.id)))

accepted_token = accepted_invitation.token
IO.puts("  Created and accepted invitation (id=#{accepted_invitation.id})")

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

==========================================
 Story 429 Seed Data — Invitation Tokens
==========================================

Owner:    qa@example.com
Account:  #{owner_account.name} (id=#{owner_account.id})
Invitee:  qa-member@example.com (role: account_manager)

PENDING INVITATION (ready to accept):
  Token:  #{pending_token}
  URL:    http://localhost:4070/invitations/#{pending_token}

ALREADY-ACCEPTED INVITATION (shows "already used" error):
  Token:  #{accepted_token}
  URL:    http://localhost:4070/invitations/#{accepted_token}

Note: Expired invitations redirect to "/" with a flash error — the acceptance
page is not shown. To test the "expired" path, use a token that has never
existed: http://localhost:4070/invitations/nonexistent-token-xyz

Credentials:
  Owner login:   qa@example.com / hello world!
  Member login:  qa-member@example.com / hello world!
  Login URL:     http://localhost:4070/users/log-in
==========================================
""")
