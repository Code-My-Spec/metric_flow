# MetricFlow.Accounts.AccountMember

Ecto schema representing the membership join between a user and an account. Stores account_id, user_id, and role. The role field uses an Ecto.Enum with values :owner, :admin, :account_manager, and :read_only. Provides a changeset validating presence of all required fields and inclusion of role in the valid enum set. The user association is preloaded by AccountRepository when returning member lists.

## Delegates

None.

## Functions

### changeset/2

Builds a changeset for creating a new account membership. Casts account_id, user_id, and role. Validates all fields are present and that role is a valid enum value. Adds a unique constraint on the {account_id, user_id} pair to prevent duplicate memberships.

```elixir
@spec changeset(AccountMember.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast :account_id, :user_id, and :role from attrs
2. Validate required fields: :account_id, :user_id, and :role
3. Validate :role is included in the Ecto.Enum values (:owner, :admin, :account_manager, :read_only)
4. Add unique_constraint on [:account_id, :user_id] to prevent duplicate memberships
5. Return the resulting changeset

**Test Assertions**:
- returns a valid changeset with all required fields present
- casts account_id from attrs
- casts user_id from attrs
- casts role from attrs
- returns invalid changeset when account_id is missing
- returns invalid changeset when user_id is missing
- returns invalid changeset when role is missing
- returns invalid changeset when role is not a valid enum value
- accepts owner as a valid role value
- accepts admin as a valid role value
- accepts account_manager as a valid role value
- accepts read_only as a valid role value
- enforces unique constraint on account_id and user_id combination

### role_changeset/2

Builds a changeset for updating only the role on an existing account membership. Used by AccountRepository when reassigning a member's role. Casts and validates only the role field.

```elixir
@spec role_changeset(AccountMember.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast only :role from attrs
2. Validate :role is included in the Ecto.Enum values (:owner, :admin, :account_manager, :read_only)
3. Return the resulting changeset

**Test Assertions**:
- returns a valid changeset when role is a valid enum value
- accepts owner as a valid role value
- accepts admin as a valid role value
- accepts account_manager as a valid role value
- accepts read_only as a valid role value
- returns invalid changeset when role is not a valid enum value
- does not cast or modify account_id
- does not cast or modify user_id
- returns invalid changeset when role is missing

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
- MetricFlow.Users.User

## Fields

| Field       | Type         | Required   | Description                         | Constraints                                                      |
| ----------- | ------------ | ---------- | ------------------------------------ | ---------------------------------------------------------------- |
| id          | integer      | Yes (auto) | Primary key                          | Auto-generated                                                   |
| account_id  | integer      | Yes        | Foreign key to the account           | References accounts.id, not null                                 |
| user_id     | integer      | Yes        | Foreign key to the user              | References users.id, not null                                    |
| role        | atom         | Yes        | Member's role in the account         | Enum: :owner, :admin, :account_manager, :read_only; not null     |
| inserted_at | utc_datetime | Yes (auto) | Record creation timestamp            | Auto-generated                                                   |
| updated_at  | utc_datetime | Yes (auto) | Record last-update timestamp         | Auto-generated                                                   |
