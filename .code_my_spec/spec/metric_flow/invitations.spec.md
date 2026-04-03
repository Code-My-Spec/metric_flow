# MetricFlow.Invitations

Invitation flow for granting account access.

Manages the full lifecycle of account invitations: creating and delivering invitation emails, validating invitation tokens, and processing acceptance or declination. Invitations are scoped to an account and grant a specific role upon acceptance. All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

## Type

context

## Delegates

- list_invitations/2: MetricFlow.Invitations.InvitationRepository.list_invitations/2
- get_invitation/2: MetricFlow.Invitations.InvitationRepository.get_invitation/2

## Functions

### send_invitation/3

Creates an invitation record and delivers an invitation email to the recipient. Only owners and admins may send invitations. The invitation is scoped to the given account_id.

```elixir
@spec send_invitation(Scope.t(), integer(), map()) ::
        {:ok, MetricFlow.Invitations.Invitation.t()} | {:error, :unauthorized | Ecto.Changeset.t()}
```

**Process**:
1. Verify the calling user has permission to invite members to the account by checking their role is `:owner` or `:admin`; return `{:error, :unauthorized}` if not permitted
2. Build an invitation changeset with `recipient_email`, `role`, `account_id`, and `invited_by_user_id` from the scope's user
3. Generate a cryptographically secure random token and store its hash on the record
4. Set `expires_at` to 7 days from the current UTC time
5. Persist the invitation record via `InvitationRepository.create_invitation/1`
6. Deliver the invitation email via `InvitationNotifier.deliver_invitation/3` with the invitation record, the account name, and a URL-building function that accepts the raw token
7. Return `{:ok, invitation}` on success or propagate the error tuple on failure

**Test Assertions**:
- returns ok tuple with Invitation struct on success for an account owner
- returns ok tuple with Invitation struct on success for an account admin
- sets recipient_email from attrs
- sets role from attrs
- sets invited_by_user_id from scope user
- sets expires_at to approximately 7 days from now
- generates a non-nil token on the invitation record
- delivers an invitation email to the recipient_email address
- returns error :unauthorized when caller role is :account_manager
- returns error :unauthorized when caller role is :read_only
- returns error changeset when recipient_email is blank
- returns error changeset when recipient_email format is invalid
- returns error changeset when role is not a valid enum value

### get_invitation_by_token/1

Looks up a pending invitation by its URL-safe token string. Returns the invitation with the associated account and inviting user preloaded when the token is valid and the invitation has not been used or expired.

```elixir
@spec get_invitation_by_token(String.t()) ::
        {:ok, MetricFlow.Invitations.Invitation.t()} | {:error, :not_found | :expired}
```

**Process**:
1. Hash the raw token to match the stored token hash via `Invitation.token_hash/1`
2. Query `InvitationRepository.get_by_token_hash/1` to fetch the invitation with `:account` and `:invited_by` preloaded
3. Return `{:error, :not_found}` when no invitation matches the hash
4. Return `{:error, :not_found}` when the invitation status is `:accepted` or `:declined`
5. Compare the invitation's `expires_at` against the current UTC time; return `{:error, :expired}` when expired
6. Return `{:ok, invitation}` when the invitation is pending and within expiry

**Test Assertions**:
- returns ok tuple with preloaded Invitation for a valid pending non-expired token
- preloads the account association on the returned invitation
- preloads the invited_by user association on the returned invitation
- returns error :not_found when token does not match any invitation
- returns error :not_found when invitation status is :accepted
- returns error :not_found when invitation status is :declined
- returns error :expired when invitation expires_at is in the past

### accept_invitation/2

Accepts a pending invitation on behalf of the authenticated user. Adds the user to the account with the invitation's role and marks the invitation as accepted. Idempotent-guards by returning an error when the user is already a member.

```elixir
@spec accept_invitation(Scope.t(), String.t()) ::
        {:ok, MetricFlow.Accounts.AccountMember.t()}
        | {:error, :not_found | :expired | :already_member}
```

**Process**:
1. Look up the invitation via `get_invitation_by_token/1`; propagate `{:error, :not_found}` or `{:error, :expired}` if the lookup fails
2. Check whether the accepting user is already a member of the invitation's account; return `{:error, :already_member}` if so
3. Execute an Ecto.Multi transaction that inserts an `AccountMember` record with the scope's `user_id`, the invitation's `account_id`, and the invitation's `role`, and also updates the invitation's `status` to `:accepted` and sets `accepted_at` to the current UTC time
4. On transaction success, broadcast `{:member_added, member}` on the `"accounts:user:#{user.id}"` PubSub topic
5. Return `{:ok, member}` on success or propagate the error tuple from the transaction

**Test Assertions**:
- returns ok tuple with AccountMember on success
- AccountMember has the role specified in the invitation
- AccountMember belongs to the invitation's account
- marks the invitation status as :accepted
- sets accepted_at on the invitation record
- broadcasts :member_added event on the accounts pubsub topic
- returns error :not_found when token does not match any invitation
- returns error :not_found when invitation has already been accepted
- returns error :not_found when invitation has already been declined
- returns error :expired when invitation has expired
- returns error :already_member when the user is already a member of the account

### decline_invitation/2

Declines a pending invitation on behalf of the authenticated user. Marks the invitation as declined without adding the user to the account.

```elixir
@spec decline_invitation(Scope.t(), String.t()) ::
        {:ok, MetricFlow.Invitations.Invitation.t()} | {:error, :not_found | :expired}
```

**Process**:
1. Look up the invitation via `get_invitation_by_token/1`; propagate `{:error, :not_found}` or `{:error, :expired}` if the lookup fails
2. Update the invitation's `status` to `:declined` via `InvitationRepository.update_invitation/2`
3. Return `{:ok, invitation}` with the updated invitation struct on success

**Test Assertions**:
- returns ok tuple with the updated Invitation on success
- marks the invitation status as :declined
- does not create an AccountMember record
- returns error :not_found when token does not match any invitation
- returns error :not_found when invitation has already been accepted
- returns error :not_found when invitation has already been declined
- returns error :expired when invitation has expired

### change_invitation/2

Returns an `%Ecto.Changeset{}` for a new invitation with the provided attrs applied. Suitable for driving live-validation on the send invitation form. Does not persist any changes.

```elixir
@spec change_invitation(Scope.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Build a changeset on a bare `%Invitation{}` struct using `Invitation.changeset/2` with the provided attrs
2. Return the changeset without persisting

**Test Assertions**:
- returns a changeset struct
- changeset is invalid when recipient_email is blank
- changeset is invalid when role is not a valid enum value
- changeset is valid when all required fields are present and valid

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Users.Scope

## Components

### MetricFlow.Invitations.Invitation

Ecto schema representing an account invitation. Stores the `recipient_email`, the granted `role` (enum matching AccountMember roles: `:owner`, `:admin`, `:account_manager`, `:read_only`), a hashed `token` used in the invitation URL, a `status` enum (`:pending`, `:accepted`, `:declined`), `expires_at`, and an optional `accepted_at` timestamp. Belongs to an `account` and to an `invited_by` user. Provides `build_token/1` for generating a `{raw_token, changeset}` pair and `token_hash/1` for deterministically hashing a raw token for database lookup.

### MetricFlow.Invitations.InvitationRepository

Data access layer for Invitation CRUD operations. All queries filter by `account_id` extracted from the Scope struct for multi-tenant isolation. Provides `create_invitation/1`, `get_by_token_hash/1` (with `:account` and `:invited_by` preloads), `list_invitations/2` for listing pending invitations scoped to an account, `get_invitation/2` for fetching a single invitation by id and scope, and `update_invitation/2` for updating invitation status fields.

### MetricFlow.Invitations.InvitationNotifier

Delivers invitation emails to recipients using Swoosh. Accepts the invitation struct, the inviting account name string, and a URL-building function that receives the raw token and returns the full invitation URL string. Formats and sends a plain-text email containing the invitation link. Returns `{:ok, email}` on successful delivery.

