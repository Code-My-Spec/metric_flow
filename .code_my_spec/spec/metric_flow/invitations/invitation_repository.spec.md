# MetricFlow.Invitations.InvitationRepository

Data access layer for Invitation CRUD operations. All queries filter by account_id for multi-tenant isolation, with the calling user's identity carried by the Scope struct. Provides create_invitation/1 for inserting a new invitation record, get_by_token_hash/1 for secure token lookup with preloaded associations, list_invitations/2 for listing pending invitations scoped to an account, get_invitation/2 for fetching a single invitation by id within an account, and update_invitation/2 for updating invitation status fields.

## Functions

### create_invitation/1

Inserts a new invitation record into the database.

```elixir
@spec create_invitation(map()) :: {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build an Invitation changeset by calling Invitation.changeset/2 with the provided attrs
2. Insert the changeset into the database with Repo.insert/1
3. Return {:ok, invitation} on success
4. Return {:error, changeset} when validation or constraint errors occur

**Test Assertions**:
- returns {:ok, invitation} with valid attrs including token_hash, email, role, expires_at, and account_id
- returns {:error, changeset} when token_hash is missing
- returns {:error, changeset} when email is missing or has invalid format
- returns {:error, changeset} when role is missing
- returns {:error, changeset} when expires_at is missing
- returns {:error, changeset} when account_id is missing
- returns {:error, changeset} when token_hash is not unique
- persists invited_by_user_id when provided
- persists invitation with status defaulting to :pending

### get_by_token_hash/1

Fetches a single invitation by its binary token hash, preloading the :account and :invited_by associations.

```elixir
@spec get_by_token_hash(binary()) :: {:ok, Invitation.t()} | {:error, :not_found}
```

**Process**:
1. Query invitations where token_hash matches the given binary value
2. Preload the :account and :invited_by associations on the result
3. Return {:ok, invitation} when a record is found
4. Return {:error, :not_found} when no record matches the token hash

**Test Assertions**:
- returns {:ok, invitation} with account and invited_by preloaded when the token hash matches
- returns {:error, :not_found} when no invitation matches the token hash
- preloads the account association
- preloads the invited_by user association
- does not apply any account-level scoping (token hash is globally unique by constraint)

### list_invitations/2

Returns all pending invitations for the given account, ordered by most recently created.

```elixir
@spec list_invitations(Scope.t(), integer()) :: list(Invitation.t())
```

**Process**:
1. Build a query filtering invitations by account_id matching the given account_id parameter
2. Add a where clause restricting results to status == :pending
3. Order by inserted_at descending, then id descending
4. Execute the query with Repo.all/1
5. Return the list of Invitation structs (empty list when none exist)

**Test Assertions**:
- returns all pending invitations for the given account_id
- returns an empty list when no pending invitations exist for the account
- does not return accepted invitations
- does not return invitations belonging to a different account
- orders results by most recently created first
- enforces multi-tenant isolation by account_id

### get_invitation/2

Fetches a single invitation by its id, scoped to the given account.

```elixir
@spec get_invitation(Scope.t(), integer()) :: {:ok, Invitation.t()} | {:error, :not_found}
```

**Process**:
1. Query invitations where id matches the given id and account_id matches the account_id from scope context
2. Execute the query with Repo.one/1
3. Return {:ok, invitation} when a matching record is found
4. Return {:error, :not_found} when no record matches or the invitation belongs to a different account

**Test Assertions**:
- returns {:ok, invitation} when the invitation exists and belongs to the given account
- returns {:error, :not_found} when the invitation id does not exist
- returns {:error, :not_found} when the invitation exists but belongs to a different account
- enforces multi-tenant isolation by account_id

### update_invitation/2

Updates an existing invitation record with the given attributes.

```elixir
@spec update_invitation(Invitation.t(), map()) :: {:ok, Invitation.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build an Invitation changeset by calling Invitation.changeset/2 with the invitation and the provided attrs
2. Update the record in the database with Repo.update/1
3. Return {:ok, updated_invitation} on success
4. Return {:error, changeset} when validation or constraint errors occur

**Test Assertions**:
- returns {:ok, invitation} with updated status when attrs are valid
- returns {:error, changeset} when attrs are invalid
- can update status from :pending to :accepted
- does not change immutable fields such as token_hash or account_id when not provided in attrs

## Dependencies

- Ecto.Query
- MetricFlow.Repo
- MetricFlow.Users.Scope
- MetricFlow.Invitations.Invitation
