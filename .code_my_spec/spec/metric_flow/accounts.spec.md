# MetricFlow.Accounts

Business accounts and membership management. Manages the full lifecycle of accounts (personal and team), account membership, role-based authorization, and PubSub notifications for real-time UI updates. All public functions accept a `%Scope{}` as the first parameter for multi-tenant isolation.

## Type

context

## Delegates

- list_accounts/1: Accounts.AccountRepository.list_accounts/1
- get_account!/2: Accounts.AccountRepository.get_account!/2
- create_team_account/2: Accounts.AccountRepository.create_team_account/2
- update_account/3: Accounts.AccountRepository.update_account/3
- delete_account/2: Accounts.AccountRepository.delete_account/2
- list_account_members/2: Accounts.AccountRepository.list_account_members/2
- get_user_role/3: Accounts.AccountRepository.get_user_role/3
- update_user_role/4: Accounts.AccountRepository.update_user_role/4
- remove_user_from_account/3: Accounts.AccountRepository.remove_user_from_account/3
- add_user_to_account/4: Accounts.AccountRepository.add_user_to_account/4

## Functions

### list_accounts/1

Returns all accounts the user belongs to, ordered by insertion date. Includes both personal and team accounts.

```elixir
@spec list_accounts(Scope.t()) :: list(Account.t())
```

**Process**:
1. Extract user_id from scope.user
2. Query the accounts table via join on account_members where user_id matches
3. Return list of Account structs ordered by inserted_at ascending

**Test Assertions**:
- returns an empty list when the user has no accounts
- returns personal and team accounts the user belongs to
- does not return accounts the user is not a member of

### get_account!/2

Fetches a single account by ID, scoped to ensure the calling user is a member of that account. Raises Ecto.NoResultsError when the account does not exist or the user is not a member.

```elixir
@spec get_account!(Scope.t(), integer()) :: Account.t()
```

**Process**:
1. Extract user_id from scope.user
2. Query the accounts table filtered by the given id and joined on account_members with matching user_id
3. Return the Account struct if found
4. Raise Ecto.NoResultsError if no record exists or user is not a member

**Test Assertions**:
- returns the account when the user is a member
- raises when the account does not exist
- raises when the user is not a member of the account

### change_account/2

Returns an Ecto.Changeset for the given account with no attrs applied, suitable for initializing a live-validation form. Does not persist any changes.

```elixir
@spec change_account(Scope.t(), Account.t()) :: Ecto.Changeset.t()
```

**Process**:
1. Delegate to Account.changeset/2 with the given account and empty attrs map
2. Return the resulting changeset without inserting or updating

**Test Assertions**:
- returns a valid changeset for an existing account
- returns a changeset with no errors when attrs are empty

### change_account/3

Returns an Ecto.Changeset for the given account with the provided attrs applied, suitable for driving live-validation. Does not persist any changes.

```elixir
@spec change_account(Scope.t(), Account.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Delegate to Account.changeset/2 with the given account and attrs
2. Return the resulting changeset without inserting or updating

**Test Assertions**:
- returns a changeset with validation errors for invalid attrs
- returns a valid changeset for valid attrs

### create_team_account/2

Creates a new team account and adds the calling user as the owner (originator). Validates required fields and slug uniqueness.

```elixir
@spec create_team_account(Scope.t(), map()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Extract user_id from scope.user
2. Build a new Account struct with type: "team" and originator_user_id set to the calling user's id
3. Apply Account.changeset/2 with the provided attrs to validate name, slug, and type
4. Begin a database transaction
5. Insert the account record
6. Insert an AccountMember record for the calling user with role: :owner
7. Broadcast {:created, account} to the account PubSub topic for the calling user
8. Return ok tuple with the persisted Account, or error tuple with the changeset

**Test Assertions**:
- creates a team account with valid attrs
- adds the calling user as the owner
- requires name to be set
- requires slug to be set and unique
- validates slug format (lowercase letters, numbers, hyphens)
- does not create account when attrs are invalid

### update_account/3

Updates an existing account's attributes. Only owners and admins may update an account. Validates the name and slug fields.

```elixir
@spec update_account(Scope.t(), Account.t(), map()) :: {:ok, Account.t()} | {:error, Ecto.Changeset.t()} | {:error, :unauthorized}
```

**Process**:
1. Check authorization via Authorization.can?(scope, :update_account, account)
2. Return {:error, :unauthorized} if the check fails
3. Apply Account.changeset/2 with the provided attrs
4. Update the account record in the database
5. Broadcast {:updated, account} to the account PubSub topic for the calling user
6. Return ok tuple with the updated Account, or error tuple with the changeset

**Test Assertions**:
- updates the account name and slug for an owner
- updates the account name and slug for an admin
- returns unauthorized for account_manager role
- returns unauthorized for read_only role
- returns changeset error for invalid slug format
- returns changeset error for duplicate slug

### delete_account/2

Deletes an account and all associated data. Only owners may delete an account. Personal accounts cannot be deleted.

```elixir
@spec delete_account(Scope.t(), Account.t()) :: {:ok, Account.t()} | {:error, :unauthorized} | {:error, :personal_account}
```

**Process**:
1. Return {:error, :personal_account} if account.type is "personal"
2. Check authorization via Authorization.can?(scope, :delete_account, account)
3. Return {:error, :unauthorized} if the check fails
4. Begin a database transaction
5. Delete all AccountMember records for the account
6. Delete the account record
7. Broadcast {:deleted, account} to the account PubSub topic for the calling user
8. Return ok tuple with the deleted Account

**Test Assertions**:
- deletes the account when called by the owner
- returns unauthorized for admin role
- returns unauthorized for account_manager role
- returns personal_account error for personal accounts
- removes all account members on deletion

### list_account_members/2

Returns all members of the given account with their associated user records preloaded. Scoped to ensure the calling user is a member of the account.

```elixir
@spec list_account_members(Scope.t(), integer()) :: list(AccountMember.t())
```

**Process**:
1. Verify the calling user is a member of the account (raises if not)
2. Query account_members filtered by account_id
3. Preload the user association on each AccountMember
4. Return the list ordered by inserted_at ascending

**Test Assertions**:
- returns all members with preloaded user data
- returns at least the calling user when they are the only member
- raises when the calling user is not a member of the account

### get_user_role/3

Returns the role of a specific user in a given account. Returns nil if the user is not a member.

```elixir
@spec get_user_role(Scope.t(), integer(), integer()) :: atom() | nil
```

**Process**:
1. Query account_members for the record with matching user_id and account_id
2. Return the role atom (:owner, :admin, :account_manager, or :read_only) if found
3. Return nil if no membership record exists

**Test Assertions**:
- returns the correct role for a member
- returns nil when the user is not a member of the account
- returns nil for a non-existent user_id

### update_user_role/4

Changes the role of a user within an account. Enforces role hierarchy: only owners can promote to owner, only owners and admins can promote to admin. The last owner of an account cannot be demoted.

```elixir
@spec update_user_role(Scope.t(), integer(), integer(), atom()) :: {:ok, AccountMember.t()} | {:error, :unauthorized} | {:error, :last_owner} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Check authorization via Authorization.can?(scope, :update_user_role, %{account_id: account_id, target_role: role})
2. Return {:error, :unauthorized} if the check fails
3. Fetch the AccountMember record for the target user_id and account_id
4. If the target member currently has role :owner, verify there is more than one owner — return {:error, :last_owner} if not
5. Apply AccountMember.changeset/2 with the new role
6. Update the record in the database
7. Broadcast {:updated, account_member} to the member PubSub topic for the calling user
8. Return ok tuple with the updated AccountMember

**Test Assertions**:
- updates the role for a valid target user
- allows an owner to promote a member to owner
- allows an owner to promote a member to admin
- allows an admin to promote a member to account_manager or read_only
- prevents an admin from promoting a member to owner
- prevents an admin from promoting a member to admin
- returns last_owner error when demoting the sole owner
- returns unauthorized for account_manager and read_only roles

### remove_user_from_account/3

Removes a user from an account. Owners and admins may remove members. The last owner of an account cannot be removed. A user cannot remove themselves if they are the last owner.

```elixir
@spec remove_user_from_account(Scope.t(), integer(), integer()) :: {:ok, AccountMember.t()} | {:error, :unauthorized} | {:error, :last_owner}
```

**Process**:
1. Check authorization via Authorization.can?(scope, :remove_member, %{account_id: account_id})
2. Return {:error, :unauthorized} if the check fails
3. Fetch the AccountMember record for the target user_id and account_id
4. If the target member has role :owner, verify there is more than one owner — return {:error, :last_owner} if not
5. Delete the AccountMember record
6. Broadcast {:deleted, account_member} to the member PubSub topic for the calling user
7. Return ok tuple with the deleted AccountMember

**Test Assertions**:
- removes a member when called by the owner
- removes a member when called by an admin
- returns last_owner error when removing the sole owner
- returns unauthorized for account_manager and read_only roles

### add_user_to_account/4

Adds a user to an account with the given role. Only owners and admins may add members. Only owners can add members with the owner role.

```elixir
@spec add_user_to_account(Scope.t(), integer(), integer(), atom()) :: {:ok, AccountMember.t()} | {:error, :unauthorized} | {:error, :already_member} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Check authorization via Authorization.can?(scope, :add_member, %{account_id: account_id, target_role: role})
2. Return {:error, :unauthorized} if the check fails
3. Check whether an AccountMember record already exists for user_id and account_id — return {:error, :already_member} if so
4. Build an AccountMember changeset with user_id, account_id, and role
5. Insert the AccountMember record
6. Broadcast {:created, account_member} to the member PubSub topic for the calling user
7. Return ok tuple with the inserted AccountMember

**Test Assertions**:
- adds a member with the given role
- returns already_member error when user is already a member
- allows owner to add a member with owner role
- prevents admin from adding a member with owner role
- returns unauthorized for account_manager and read_only roles

### subscribe_account/1

Subscribes the calling process to PubSub broadcasts for account-level events (created, updated, deleted) scoped to the current user.

```elixir
@spec subscribe_account(Scope.t()) :: :ok | {:error, term()}
```

**Process**:
1. Extract user_id from scope.user
2. Subscribe to the Phoenix.PubSub topic "accounts:user:#{user_id}"
3. Return :ok on success

**Test Assertions**:
- subscribes to the account topic
- receives {:created, account} message after create_team_account
- receives {:updated, account} message after update_account
- receives {:deleted, account} message after delete_account

### subscribe_member/1

Subscribes the calling process to PubSub broadcasts for member-level events (created, updated, deleted) scoped to the current user.

```elixir
@spec subscribe_member(Scope.t()) :: :ok | {:error, term()}
```

**Process**:
1. Extract user_id from scope.user
2. Subscribe to the Phoenix.PubSub topic "account_members:user:#{user_id}"
3. Return :ok on success

**Test Assertions**:
- subscribes to the member topic
- receives {:created, account_member} message after add_user_to_account
- receives {:updated, account_member} message after update_user_role
- receives {:deleted, account_member} message after remove_user_from_account

## Dependencies

## Components

### MetricFlow.Accounts.Account

Ecto schema representing a business account. Stores account name, URL-friendly slug, account type (personal or team), and the originator_user_id tracking who created the account. Provides changesets validating name presence, slug format (lowercase letters, numbers, and hyphens), and slug uniqueness. The type field is read-only after creation. Personal accounts are auto-created during user registration; team accounts are created explicitly by users.

### MetricFlow.Accounts.AccountMember

Ecto schema representing the membership join between a user and an account. Stores account_id, user_id, and role. The role field uses an Ecto.Enum with values :owner, :admin, :account_manager, and :read_only. Provides a changeset validating presence of all required fields and inclusion of role in the valid enum set. The user association is preloaded by AccountRepository when returning member lists.

### MetricFlow.Accounts.AccountRepository

Data access layer for Account and AccountMember CRUD operations. All query functions filter by the calling user's identity extracted from the Scope struct for multi-tenant isolation. Handles transactional operations — account creation atomically inserts the account and owner membership record, and account deletion atomically removes all member records before removing the account. Broadcasts PubSub events after successful mutations.

### MetricFlow.Accounts.Authorization

Role-based authorization module providing can?/3 predicate functions for all account operations. Accepts a Scope struct, an action atom, and an optional subject struct. Encodes the role hierarchy: owner > admin > account_manager > read_only. Owners may perform all actions. Admins may update accounts, add/remove/update members up to their own role level. Account managers and read-only users have no write permissions. Protects against last-owner removal and demotion by checking membership counts before returning authorization decisions.

## Fields

### MetricFlow.Accounts.Account

| Field              | Type         | Required   | Description                                          | Constraints                                    |
| ------------------ | ------------ | ---------- | ---------------------------------------------------- | ---------------------------------------------- |
| id                 | integer      | Yes (auto) | Primary key                                          | Auto-generated                                 |
| name               | string       | Yes        | Human-readable account name                          | Min: 1, Max: 255                               |
| slug               | string       | Yes        | URL-friendly identifier                              | Unique, lowercase letters/numbers/hyphens only |
| type               | string       | Yes        | Account type: "personal" or "team"                   | Inclusion in ["personal", "team"]              |
| originator_user_id | integer      | Yes        | ID of the user who created the account               | References users.id                            |
| inserted_at        | utc_datetime | Yes (auto) | Record creation timestamp                            | Auto-generated                                 |
| updated_at         | utc_datetime | Yes (auto) | Record last-update timestamp                         | Auto-generated                                 |

### MetricFlow.Accounts.AccountMember

| Field       | Type         | Required   | Description                                           | Constraints                                              |
| ----------- | ------------ | ---------- | ----------------------------------------------------- | -------------------------------------------------------- |
| id          | integer      | Yes (auto) | Primary key                                           | Auto-generated                                           |
| account_id  | integer      | Yes        | Foreign key to the account                            | References accounts.id, not null                         |
| user_id     | integer      | Yes        | Foreign key to the user                               | References users.id, not null                            |
| role        | atom         | Yes        | Member's role in the account                          | Enum: owner, admin, account_manager, read_only; not null |
| inserted_at | utc_datetime | Yes (auto) | Record creation timestamp                             | Auto-generated                                           |
| updated_at  | utc_datetime | Yes (auto) | Record last-update timestamp                          | Auto-generated                                           |

