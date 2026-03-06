# MetricFlow.Agencies.AgencyClientAccessGrant

Ecto schema representing an agency's access grant to a client account. Stores the agency_account_id, client_account_id, access_level, and origination_status. The origination_status distinguishes whether the agency originated the client account (:originator) or was invited (:invited). Enforces a unique constraint on (agency_account_id, client_account_id) to ensure at most one grant per agency-client pair.

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| agency_account_id | integer | Yes | Foreign key to the agency account | References accounts.id (integer primary key) |
| client_account_id | integer | Yes | Foreign key to the client account | References accounts.id (integer primary key) |
| access_level | Ecto.Enum | Yes | Level of access the agency has over the client account | Must be one of: :read_only, :account_manager, :admin |
| origination_status | Ecto.Enum | No | Whether the agency originated the client or was invited | Must be one of: :invited, :originator; defaults to :invited |
| inserted_at | utc_datetime | Yes (auto) | Timestamp when record was created | Auto-generated |
| updated_at | utc_datetime | Yes (auto) | Timestamp when record was last updated | Auto-generated |

## Functions

### changeset/2

Creates an Ecto changeset for creating or updating an AgencyClientAccessGrant record. Validates required fields, association constraints, and enforces unique constraint on the agency-client pair.

```elixir
@spec changeset(AgencyClientAccessGrant.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: agency_account_id, client_account_id, access_level, origination_status
2. Validate required fields: agency_account_id, client_account_id, access_level
3. Add association constraint on agency_account (ensures referenced account exists)
4. Add association constraint on client_account (ensures referenced account exists)
5. Add unique constraint on (agency_account_id, client_account_id) to prevent duplicate grants
6. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset with all required fields
- Casts agency_account_id correctly
- Casts client_account_id correctly
- Casts access_level correctly
- Casts origination_status correctly
- Validates agency_account_id is required
- Validates client_account_id is required
- Validates access_level is required
- Allows origination_status to be omitted (defaults to :invited)
- Validates access_level is one of allowed enum values
- Rejects invalid access_level values (e.g., :owner, :viewer)
- Accepts :read_only as access_level
- Accepts :account_manager as access_level
- Accepts :admin as access_level
- Validates origination_status is one of allowed enum values
- Rejects invalid origination_status values (e.g., :pending, :rejected)
- Accepts :invited as origination_status
- Accepts :originator as origination_status
- Validates agency_account association exists (assoc_constraint triggers on insert)
- Validates client_account association exists (assoc_constraint triggers on insert)
- Enforces unique constraint on agency_account_id and client_account_id combination
- Allows same agency_account_id with different client_account_id values
- Allows same client_account_id with different agency_account_id values
- Creates valid changeset for updating existing grant
- Preserves existing fields when updating subset of attributes
- Handles empty attributes map gracefully

### originator_changeset/2

Creates an Ecto changeset for updating only the origination_status on an existing AgencyClientAccessGrant record.

```elixir
@spec originator_changeset(AgencyClientAccessGrant.t(), map()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast attributes: origination_status only
2. Validate required fields: origination_status
3. Return changeset with validations applied

**Test Assertions**:
- Creates valid changeset when origination_status is provided
- Validates origination_status is required
- Accepts :invited as origination_status
- Accepts :originator as origination_status
- Rejects invalid origination_status values (e.g., :pending)
- Does not cast or modify agency_account_id
- Does not cast or modify client_account_id
- Does not cast or modify access_level
- Handles empty attributes map by marking origination_status as missing

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Accounts.Account
