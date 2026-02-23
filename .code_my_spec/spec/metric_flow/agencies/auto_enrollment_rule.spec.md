# MetricFlow.Agencies.AutoEnrollmentRule

Ecto schema representing domain-based auto-enrollment configuration for agency accounts. Stores email domain patterns, enabled status, and default access level for auto-enrolled users. Enforces one rule per agency via unique constraint. Provides changeset validation for domain format and access level values.

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| agency_id | binary_id | Yes | Foreign key to agency account | References accounts.id |
| email_domain | string | Yes | Email domain pattern to match (e.g., "example.com") | Must be valid domain format, unique per agency |
| default_access_level | Ecto.Enum | Yes | Default access level for auto-enrolled users | Must be one of: :read_only, :account_manager, :admin |
| enabled | boolean | No | Whether auto-enrollment is active for this rule | Defaults to true |
| inserted_at | utc_datetime | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating an AutoEnrollmentRule record. Validates all required fields, type constraints, associations, and enforces unique constraint on agency/domain combination.

```elixir
@spec changeset(AutoEnrollmentRule.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: agency_id, email_domain, default_access_level, enabled
2. Validate required fields: agency_id, email_domain, default_access_level
3. Validate email_domain format matches valid domain pattern (lowercase letters, numbers, dots, hyphens)
4. Validate default_access_level is one of: :read_only, :account_manager, :admin
5. Add association constraint on agency (ensures referenced account exists)
6. Add unique constraint on [:agency_id, :email_domain] to prevent duplicate rules
7. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts agency_id correctly
- Casts email_domain correctly
- Casts default_access_level correctly
- Casts enabled correctly
- Validates agency_id is required
- Validates email_domain is required
- Validates default_access_level is required
- Allows enabled to default to true when not provided
- Validates email_domain format is valid (e.g., "example.com")
- Rejects email_domain with invalid characters (e.g., spaces, @ symbols)
- Rejects email_domain with uppercase letters
- Accepts email_domain with subdomains (e.g., "mail.example.com")
- Accepts email_domain with hyphens (e.g., "my-company.com")
- Validates default_access_level is one of allowed enum values
- Rejects invalid default_access_level values (e.g., :owner, :member)
- Accepts :read_only as default_access_level
- Accepts :account_manager as default_access_level
- Accepts :admin as default_access_level
- Validates agency association exists (assoc_constraint triggers on insert)
- Enforces unique constraint on agency_id and email_domain combination
- Allows same email_domain for different agencies
- Allows different email_domains for same agency
- Creates valid changeset for updating existing rule
- Preserves existing fields when updating subset of attributes
- Allows disabling rule by setting enabled to false
- Allows re-enabling rule by setting enabled to true
- Handles empty attributes map gracefully

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
