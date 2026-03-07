# MetricFlow.Invitations.Invitation

Ecto schema representing an account access invitation.

An invitation is created by an account owner or admin and sent to a target email address. It carries a hashed token (the raw token is delivered to the invitee and never stored), the target role, a status enum, and an expiry timestamp. Invitations expire after 7 days. Accepted invitations cannot be reused. Belongs to an `account` and to the `invited_by` user who created the invitation.

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| token_hash | binary | Yes | SHA-256 hash of the raw invitation token | Unique across all invitations |
| email | string | Yes | Email address of the invited recipient | Must match valid email format |
| role | Ecto.Enum | Yes | Role granted to the recipient upon acceptance | One of: :owner, :admin, :account_manager, :read_only |
| status | Ecto.Enum | Yes | Current lifecycle state of the invitation | One of: :pending, :accepted; defaults to :pending |
| expires_at | utc_datetime | Yes | UTC timestamp when the invitation expires | Set to 7 days from creation by the caller |
| account_id | integer | Yes | Foreign key to the accounts table | References MetricFlow.Accounts.Account |
| invited_by_user_id | integer | No | Foreign key to the users table for the inviter | References MetricFlow.Users.User; optional (system invites allowed) |
| inserted_at | utc_datetime | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Builds a changeset for creating a new invitation. Validates all required fields, enforces email format, applies association constraints, and enforces uniqueness of the token hash.

```elixir
@spec changeset(Invitation.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: token_hash, email, role, status, expires_at, account_id, invited_by_user_id
2. Validate required fields: token_hash, email, role, expires_at, account_id
3. Validate email format matches the pattern `^[^\s]+@[^\s]+\.[^\s]+$`; produce error message "must be a valid email address" on failure
4. Add foreign key constraint on account_id to ensure the referenced account exists
5. Add foreign key constraint on invited_by_user_id to ensure the referenced user exists when provided
6. Add unique constraint on token_hash to prevent token collisions
7. Return the changeset with all validations applied

**Test Assertions**:
- creates a valid changeset when all required fields are present and valid
- casts token_hash correctly
- casts email correctly
- casts role correctly
- casts status correctly
- casts expires_at correctly
- casts account_id correctly
- casts invited_by_user_id correctly
- validates token_hash is required
- validates email is required
- validates role is required
- validates expires_at is required
- validates account_id is required
- allows nil invited_by_user_id (optional field)
- rejects email that does not contain an @ symbol
- rejects email that contains whitespace
- rejects email that is missing a domain suffix
- accepts all valid role enum values (:owner, :admin, :account_manager, :read_only)
- rejects an invalid role value not in the enum
- accepts :pending status
- accepts :accepted status
- defaults status to :pending when not provided
- adds foreign_key_constraint error on account_id when account does not exist
- adds foreign_key_constraint error on invited_by_user_id when user does not exist
- enforces unique constraint on token_hash

### accept_changeset/1

Builds a changeset for marking an existing invitation as accepted. Applies only the status change without requiring any additional attributes.

```elixir
@spec accept_changeset(Invitation.t()) :: Ecto.Changeset.t()
```

**Process**:
1. Apply a change setting status to :accepted on the given invitation struct
2. Validate that status is present to ensure the change is not inadvertently nil
3. Return the changeset

**Test Assertions**:
- returns a valid changeset with status set to :accepted
- does not require any attrs argument
- preserves all other existing fields on the invitation
- changeset is valid when applied to a :pending invitation
- changeset is valid when applied to an already :accepted invitation
- status field in the changeset is :accepted

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
- MetricFlow.Users.User
