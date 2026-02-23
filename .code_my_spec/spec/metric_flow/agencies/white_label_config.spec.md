# MetricFlow.Agencies.WhiteLabelConfig

Ecto schema for agency white-label branding configuration. Stores logo URL, primary and secondary brand colors, and custom subdomain. Enforces unique subdomain constraint. Validates hex color format and subdomain format (lowercase letters, numbers, hyphens).

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| agency_id | binary_id | Yes | Foreign key to agencies (accounts) table | References MetricFlow.Accounts.Account |
| logo_url | string | No | URL to agency's logo image | Must be valid URL format, max 500 characters |
| primary_color | string | No | Primary brand color in hex format | Must be valid hex color (e.g., #FF5733), 7 characters including # |
| secondary_color | string | No | Secondary brand color in hex format | Must be valid hex color (e.g., #3498DB), 7 characters including # |
| subdomain | string | Yes | Unique subdomain for white-label instance | Lowercase letters, numbers, hyphens only; min 3, max 63 characters; must be unique |
| custom_css | text | No | Optional custom CSS overrides | Text field for custom styling |
| inserted_at | utc_datetime | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating a WhiteLabelConfig record. Validates subdomain format and uniqueness, validates hex color formats, and ensures association with an agency account.

```elixir
@spec changeset(WhiteLabelConfig.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: agency_id, logo_url, primary_color, secondary_color, subdomain, custom_css
2. Validate required fields: agency_id, subdomain
3. Validate subdomain format (lowercase letters, numbers, hyphens only)
4. Validate subdomain length (min 3, max 63 characters)
5. Validate primary_color format as hex color (7 characters starting with #)
6. Validate secondary_color format as hex color (7 characters starting with #)
7. Validate logo_url format and length (max 500 characters)
8. Add association constraint on agency (ensures referenced account exists)
9. Add unique constraint on subdomain to prevent duplicates
10. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts agency_id correctly
- Casts subdomain correctly
- Casts logo_url correctly
- Casts primary_color correctly
- Casts secondary_color correctly
- Casts custom_css correctly
- Validates agency_id is required
- Validates subdomain is required
- Validates subdomain format accepts lowercase letters
- Validates subdomain format accepts numbers
- Validates subdomain format accepts hyphens
- Rejects subdomain with uppercase letters
- Rejects subdomain with special characters other than hyphens
- Rejects subdomain with spaces
- Validates subdomain minimum length of 3 characters
- Validates subdomain maximum length of 63 characters
- Validates primary_color is valid hex format (#RRGGBB)
- Rejects primary_color without hash prefix
- Rejects primary_color with invalid length
- Rejects primary_color with non-hex characters
- Allows nil primary_color as optional
- Validates secondary_color is valid hex format (#RRGGBB)
- Rejects secondary_color without hash prefix
- Rejects secondary_color with invalid length
- Rejects secondary_color with non-hex characters
- Allows nil secondary_color as optional
- Validates logo_url maximum length of 500 characters
- Allows nil logo_url as optional
- Allows nil custom_css as optional
- Validates agency association exists (assoc_constraint triggers on insert)
- Enforces unique constraint on subdomain
- Allows same subdomain if previous config is deleted
- Creates valid changeset for updating existing config
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
