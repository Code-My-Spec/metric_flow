# MetricFlow.Agencies.AgenciesRepository

Data access layer for agency features — handles CRUD for auto-enrollment rules, white-label configs, team members, and client account access.

## Functions

### get_auto_enrollment_rule/1

Retrieves the auto-enrollment rule for a specific account.

```elixir
@spec get_auto_enrollment_rule(String.t()) :: AutoEnrollmentRule.t() | nil
```

**Process**:
1. Query AutoEnrollmentRule by account_id
2. Execute query with Repo.one()
3. Return rule if found, nil otherwise

**Test Assertions**:
- Returns auto-enrollment rule when one exists for account
- Returns nil when no rule exists for account
- Returns nil when account_id doesn't match

### create_auto_enrollment_rule/1

Creates a new auto-enrollment rule for an agency account.

```elixir
@spec create_auto_enrollment_rule(map()) :: {:ok, AutoEnrollmentRule.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build AutoEnrollmentRule changeset with attrs
2. Validate required fields (account_id, domain, enabled, default_access_level)
3. Validate domain format
4. Validate default_access_level is one of: read_only, account_manager, admin
5. Insert into database with Repo.insert()
6. Return ok tuple with rule or error with changeset

**Test Assertions**:
- Creates rule with valid attributes
- Returns error when domain is invalid format
- Returns error when default_access_level is invalid
- Returns error when account_id is missing
- Enforces unique constraint on domain
- Stores enabled flag

### update_auto_enrollment_rule/2

Updates an existing auto-enrollment rule.

```elixir
@spec update_auto_enrollment_rule(AutoEnrollmentRule.t(), map()) :: {:ok, AutoEnrollmentRule.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build changeset from existing rule and attrs
2. Validate domain format if changed
3. Validate default_access_level if changed
4. Update rule with Repo.update()
5. Return ok tuple with updated rule or error with changeset

**Test Assertions**:
- Updates rule with valid attributes
- Allows updating domain
- Allows updating enabled flag
- Allows updating default_access_level
- Returns error with invalid attributes
- Enforces unique constraint on domain

### list_auto_enrollment_rules/1

Lists all auto-enrollment rules for a specific account.

```elixir
@spec list_auto_enrollment_rules(String.t()) :: list(AutoEnrollmentRule.t())
```

**Process**:
1. Build query filtering by account_id
2. Execute query with Repo.all()
3. Return list of rules (empty if none exist)

**Test Assertions**:
- Returns all rules for specified account
- Returns empty list when no rules exist
- Does not return rules for other accounts
- Orders by inserted_at descending

### find_matching_rule/2

Finds an active auto-enrollment rule matching the given email domain.

```elixir
@spec find_matching_rule(String.t(), String.t()) :: AutoEnrollmentRule.t() | nil
```

**Process**:
1. Extract domain from email address
2. Build query filtering by domain and enabled: true
3. Execute query with Repo.one()
4. Return matching rule or nil

**Test Assertions**:
- Returns rule when domain matches and enabled is true
- Returns nil when domain matches but enabled is false
- Returns nil when no rule matches domain
- Case-insensitive domain matching
- Handles email addresses with subdomains correctly

### list_team_members/1

Lists all team members for an agency account.

```elixir
@spec list_team_members(String.t()) :: list(Member.t())
```

**Process**:
1. Build query joining Members with Users
2. Filter by account_id
3. Preload user associations
4. Order by inserted_at descending
5. Execute query with Repo.all()
6. Return list of members

**Test Assertions**:
- Returns all team members for specified account
- Preloads user associations
- Returns empty list when no members exist
- Orders by most recently added
- Does not return members from other accounts

### add_team_member/2

Adds a user to an agency team.

```elixir
@spec add_team_member(integer(), String.t()) :: {:ok, Member.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build Member changeset with user_id, account_id, and role
2. Validate required fields
3. Insert member with Repo.insert()
4. Return ok tuple with member or error with changeset

**Test Assertions**:
- Creates member with specified user_id and account_id
- Defaults to member role if not specified
- Returns error for duplicate membership
- Validates user_id exists
- Validates account_id exists

### remove_team_member/2

Removes a user from an agency team.

```elixir
@spec remove_team_member(integer(), String.t()) :: {:ok, Member.t()} | {:error, :not_found}
```

**Process**:
1. Query Member by user_id and account_id
2. Return error if member not found
3. Delete member with Repo.delete()
4. Return ok tuple with deleted member

**Test Assertions**:
- Deletes member when found
- Returns error when member not found
- Does not affect members of other accounts
- Returns deleted member struct

### list_client_accounts/1

Lists all client accounts that an agency has access to.

```elixir
@spec list_client_accounts(String.t()) :: list(map())
```

**Process**:
1. Build query joining Accounts through access grants
2. Filter by agency_account_id
3. Include access_level and origination_status
4. Order by inserted_at descending
5. Execute query with Repo.all()
6. Return list of account maps with access metadata

**Test Assertions**:
- Returns all client accounts agency has access to
- Includes access_level for each account
- Includes origination_status (originator or invited)
- Returns empty list when no access exists
- Orders by most recently created
- Does not return accounts agency has no access to

### get_client_access/2

Retrieves an agency's access details for a specific client account.

```elixir
@spec get_client_access(String.t(), String.t()) :: map() | nil
```

**Process**:
1. Query access grant by agency_account_id and client_account_id
2. Execute query with Repo.one()
3. Return map with access_level and origination_status or nil

**Test Assertions**:
- Returns access details when agency has access
- Returns nil when agency has no access
- Includes access_level
- Includes origination_status

### grant_client_access/3

Grants an agency access to a client account.

```elixir
@spec grant_client_access(String.t(), String.t(), atom()) :: {:ok, map()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build access grant changeset with agency_account_id, client_account_id, and access_level
2. Validate access_level is one of: read_only, account_manager, admin
3. Insert or update access grant with upsert
4. Set conflict_target to [:agency_account_id, :client_account_id]
5. Return ok tuple with access grant or error with changeset

**Test Assertions**:
- Creates access grant with valid attributes
- Updates existing access grant when one exists
- Returns error when access_level is invalid
- Validates agency_account_id exists
- Validates client_account_id exists

### revoke_client_access/2

Revokes an agency's access to a client account.

```elixir
@spec revoke_client_access(String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
```

**Process**:
1. Query access grant by agency_account_id and client_account_id
2. Return error if access grant not found
3. Delete access grant with Repo.delete()
4. Return ok tuple with deleted access grant

**Test Assertions**:
- Deletes access grant when found
- Returns error when access grant not found
- Does not affect other access grants
- Returns deleted access grant map

### list_account_agencies/1

Lists all agencies that have access to a specific client account.

```elixir
@spec list_account_agencies(String.t()) :: list(map())
```

**Process**:
1. Build query joining Accounts through access grants
2. Filter by client_account_id
3. Include agency details, access_level, and origination_status
4. Order by origination_status (originators first), then by inserted_at
5. Execute query with Repo.all()
6. Return list of agency maps with access metadata

**Test Assertions**:
- Returns all agencies with access to specified account
- Includes access_level for each agency
- Includes origination_status
- Orders by originator first, then by date
- Returns empty list when no agencies have access
- Does not return agencies without access

### get_white_label_config/1

Retrieves white-label configuration for an agency account.

```elixir
@spec get_white_label_config(String.t()) :: WhiteLabelConfig.t() | nil
```

**Process**:
1. Query WhiteLabelConfig by account_id
2. Execute query with Repo.one()
3. Return config if found, nil otherwise

**Test Assertions**:
- Returns white-label config when one exists
- Returns nil when no config exists
- Returns nil when account_id doesn't match

### upsert_white_label_config/2

Creates or updates white-label configuration for an agency.

```elixir
@spec upsert_white_label_config(String.t(), map()) :: {:ok, WhiteLabelConfig.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build WhiteLabelConfig changeset with account_id and attrs
2. Validate logo_url format if present
3. Validate primary_color and secondary_color are valid hex colors
4. Validate subdomain format and uniqueness
5. Insert with on_conflict option: {:replace_all_except, [:id, :inserted_at]}
6. Set conflict_target to [:account_id]
7. Return ok tuple with config or error with changeset

**Test Assertions**:
- Creates new config when none exists
- Updates existing config when one exists
- Validates hex color format
- Validates subdomain format
- Enforces unique subdomain constraint
- Allows nil values for optional fields

### mark_as_originator/2

Marks an agency as the originator of a client account.

```elixir
@spec mark_as_originator(String.t(), String.t()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Query access grant by agency_account_id and client_account_id
2. Return error if access grant not found
3. Update access grant with origination_status: :originator
4. Return ok tuple with updated access grant

**Test Assertions**:
- Updates origination_status to originator when access exists
- Returns error when access grant not found
- Does not affect other access grants
- Returns updated access grant map

### originated_by?/2

Checks if a client account was originated by a specific agency.

```elixir
@spec originated_by?(String.t(), String.t()) :: boolean()
```

**Process**:
1. Build query filtering by agency_account_id, client_account_id, and origination_status: :originator
2. Execute query with Repo.exists?()
3. Return boolean result

**Test Assertions**:
- Returns true when agency is marked as originator
- Returns false when agency is not originator
- Returns false when agency has no access
- Returns false when access grant doesn't exist

## Dependencies

- Ecto.Query
- MetricFlow.Infrastructure.Repo
- MetricFlow.Agencies.AutoEnrollmentRule
- MetricFlow.Agencies.WhiteLabelConfig
- MetricFlow.Accounts.Member
