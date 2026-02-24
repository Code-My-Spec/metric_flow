# MetricFlow.Accounts.Account

Ecto schema representing a business account. Stores account name, URL-friendly slug, account type (personal or team), and the originator_user_id tracking who created the account. Provides changesets validating name presence, slug format (lowercase letters, numbers, and hyphens), and slug uniqueness. The type field is read-only after creation. Personal accounts are auto-created during user registration; team accounts are created explicitly by users.

## Delegates

None.

## Functions

### changeset/2

Builds a changeset for updating an existing account's name and slug. Does not cast type or originator_user_id, as those fields are set at creation time only and are immutable thereafter.

```elixir
@spec changeset(Account.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast :name and :slug from attrs
2. Validate :name is present using validate_required/2
3. Validate :name length does not exceed 255 characters
4. Validate :slug is present using validate_required/2
5. Validate :slug matches format ~r/^[a-z0-9-]+$/ (lowercase letters, numbers, and hyphens only)
6. Add unique_constraint on :slug
7. Return the resulting changeset

**Test Assertions**:
- returns a valid changeset for a valid name and slug
- returns an error when name is absent
- returns an error when name exceeds 255 characters
- returns an error when slug is absent
- returns an error when slug contains uppercase letters
- returns an error when slug contains spaces
- returns an error when slug contains special characters other than hyphens
- returns an error when slug is not unique
- does not cast type when provided in attrs
- does not cast originator_user_id when provided in attrs

### creation_changeset/2

Builds a changeset for inserting a new account. Casts all required fields including type and originator_user_id. This is the only changeset that sets type and originator_user_id, which are immutable after creation.

```elixir
@spec creation_changeset(Account.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast :name, :slug, :type, and :originator_user_id from attrs
2. Validate :name is present using validate_required/2
3. Validate :name length does not exceed 255 characters
4. Validate :slug is present using validate_required/2
5. Validate :slug matches format ~r/^[a-z0-9-]+$/ (lowercase letters, numbers, and hyphens only)
6. Validate :type is present using validate_required/2
7. Validate :type is included in ["personal", "team"]
8. Validate :originator_user_id is present using validate_required/2
9. Add unique_constraint on :slug
10. Return the resulting changeset

**Test Assertions**:
- returns a valid changeset for all valid fields
- returns an error when name is absent
- returns an error when slug is absent
- returns an error when slug format is invalid
- returns an error when type is absent
- returns an error when type is not personal or team
- returns an error when originator_user_id is absent
- returns an error when slug is not unique
- accepts type personal
- accepts type team

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Repo

## Fields

| Field              | Type         | Required   | Description                                          | Constraints                                    |
| ------------------ | ------------ | ---------- | ---------------------------------------------------- | ---------------------------------------------- |
| id                 | integer      | Yes (auto) | Primary key                                          | Auto-generated                                 |
| name               | string       | Yes        | Human-readable account name                          | Min: 1, Max: 255                               |
| slug               | string       | Yes        | URL-friendly identifier                              | Unique, lowercase letters/numbers/hyphens only |
| type               | string       | Yes        | Account type: "personal" or "team"                   | Inclusion in ["personal", "team"]              |
| originator_user_id | integer      | Yes        | ID of the user who created the account               | References users.id                            |
| inserted_at        | utc_datetime | Yes (auto) | Record creation timestamp                            | Auto-generated                                 |
| updated_at         | utc_datetime | Yes (auto) | Record last-update timestamp                         | Auto-generated                                 |
