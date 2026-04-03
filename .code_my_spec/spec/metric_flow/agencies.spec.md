# MetricFlow.Agencies

Agency-specific features: team management, white-labeling, client account origination.

## Type

context

## Delegates

- get_auto_enrollment_rule/2: MetricFlow.Agencies.AgenciesRepository.get_auto_enrollment_rule/2
- get_white_label_config/2: MetricFlow.Agencies.AgenciesRepository.get_white_label_config/2
- list_agency_client_accounts/2: MetricFlow.Agencies.AgenciesRepository.list_agency_client_accounts/2
- list_agency_team_members/2: MetricFlow.Agencies.AgenciesRepository.list_agency_team_members/2

## Functions

### configure_auto_enrollment/3

Configures domain-based auto-enrollment settings for an agency account.

```elixir
@spec configure_auto_enrollment(Scope.t(), String.t(), map()) :: {:ok, AutoEnrollmentRule.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Verify user has admin access to the agency account via Authorization
2. Build AutoEnrollmentRule changeset with provided attributes (domain, enabled, default_access_level)
3. Validate domain format and uniqueness
4. Validate default_access_level is one of: read_only, account_manager, admin
5. Upsert auto-enrollment rule via AgenciesRepository
6. Return ok tuple with saved rule, or error with changeset

**Test Assertions**:
- returns ok tuple with auto-enrollment rule when valid
- requires admin authorization on agency account
- validates domain is valid email domain format
- validates default_access_level is one of allowed values
- returns error for duplicate domain across agencies
- allows disabling auto-enrollment by setting enabled to false
- updates existing rule when one exists for the account

### get_auto_enrollment_rule/2

Retrieves the auto-enrollment configuration for an agency account. Delegates to AgenciesRepository.

```elixir
@spec get_auto_enrollment_rule(Scope.t(), String.t()) :: AutoEnrollmentRule.t() | nil
```

**Test Assertions**:
- returns auto-enrollment rule when one exists
- returns nil when no rule configured
- requires read access to agency account

### process_new_user_auto_enrollment/2

Evaluates whether a newly registered user should be auto-enrolled in an agency and applies enrollment if matched.

```elixir
@spec process_new_user_auto_enrollment(User.t(), String.t()) :: {:ok, list(Member.t())} | {:ok, :no_match}
```

**Process**:
1. Extract email domain from user's email address
2. Query AgenciesRepository for active auto-enrollment rules matching the domain
3. Return :no_match if no matching rules found
4. For each matching rule, create agency team membership via add_agency_team_member/3
5. Use the rule's default_access_level for the member role
6. Grant inherited access to all client accounts managed by the agency
7. Return ok tuple with list of created memberships

**Test Assertions**:
- returns no_match when user email domain doesn't match any rules
- returns no_match when matching rule is disabled
- creates team membership with configured default_access_level
- grants access to all client accounts the agency manages
- handles multiple agency matches for same domain
- inherits proper access level (read_only, account_manager, admin)

### add_agency_team_member/3

Adds a user to an agency team with specified access level.

```elixir
@spec add_agency_team_member(Scope.t(), integer(), atom()) :: {:ok, Member.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Verify caller has admin access to the agency account
2. Validate access_level is one of: read_only, account_manager, admin
3. Create Member record linking user to agency account with specified role
4. Grant inherited access to all client accounts managed by the agency
5. Return ok tuple with created member, or error with changeset

**Test Assertions**:
- requires admin authorization on agency account
- creates member with specified access level
- grants inherited access to agency's client accounts
- returns error for duplicate membership
- returns error for invalid access level

### list_agency_team_members/2

Lists all team members of an agency account. Delegates to AgenciesRepository.

```elixir
@spec list_agency_team_members(Scope.t(), String.t()) :: list(Member.t())
```

**Test Assertions**:
- returns list of agency team members
- requires admin access to agency account
- includes member user associations
- orders by most recently added

### remove_agency_team_member/3

Removes a user from an agency team and revokes inherited client account access.

```elixir
@spec remove_agency_team_member(Scope.t(), integer(), String.t()) :: {:ok, Member.t()} | {:error, term()}
```

**Process**:
1. Verify caller has admin access to the agency account
2. Revoke user's access to all client accounts that were inherited from agency
3. Remove user's membership from the agency account
4. Return ok tuple with deleted member, or error

**Test Assertions**:
- requires admin authorization on agency account
- revokes inherited access to all client accounts
- maintains user's direct (non-inherited) client account access
- returns ok tuple with deleted member
- returns error when member not found

### list_agency_client_accounts/2

Lists all client accounts accessible to an agency. Delegates to AgenciesRepository.

```elixir
@spec list_agency_client_accounts(Scope.t(), String.t()) :: list(map())
```

**Test Assertions**:
- returns list of client accounts with access metadata
- includes access_level for each client account
- includes origination_status (originator or invited)
- requires read access to agency account
- orders by most recently created

### get_client_account_access/3

Retrieves an agency's access level and origination status for a specific client account.

```elixir
@spec get_client_account_access(Scope.t(), String.t(), String.t()) :: {:ok, map()} | {:error, :not_found}
```

**Process**:
1. Verify caller has read access to the agency account
2. Query AgenciesRepository for agency's access to the client account
3. Return map with access_level, origination_status, and permissions
4. Return error if agency has no access to the client account

**Test Assertions**:
- returns ok tuple with access metadata when agency has access
- includes access_level (read_only, account_manager, admin, owner)
- includes origination_status (originator or invited)
- includes permissions map with can_view_reports, can_modify_integrations, can_manage_users, can_delete_account
- returns error when agency has no access
- requires read access to agency account

### grant_client_account_access/5

Grants an agency access to a client account with specified access level.

```elixir
@spec grant_client_account_access(Scope.t(), String.t(), String.t(), atom(), boolean()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Verify caller has admin access to the client account being shared
2. Validate access_level is one of: read_only, account_manager, admin
3. Create access grant record linking agency to client account
4. Set origination flag (true if agency created the account, false if invited)
5. Propagate access to all agency team members with inherited permissions
6. Return ok tuple with access grant, or error

**Test Assertions**:
- requires admin access to client account
- creates access grant with specified level
- sets origination_status correctly
- propagates access to all agency team members
- returns error for invalid access level
- allows updating existing access level

### revoke_client_account_access/3

Revokes an agency's access to a client account.

```elixir
@spec revoke_client_account_access(Scope.t(), String.t(), String.t()) :: {:ok, map()} | {:error, term()}
```

**Process**:
1. Verify caller has admin access to the client account
2. Verify agency is not the originator (originator access cannot be revoked)
3. Remove access grant record
4. Revoke access from all agency team members
5. Return ok tuple with revoked access grant, or error

**Test Assertions**:
- requires admin access to client account
- removes access grant and member permissions
- returns error when agency is originator
- returns error when agency has no access

### get_white_label_config/2

Retrieves white-label branding configuration for an agency. Delegates to AgenciesRepository.

```elixir
@spec get_white_label_config(Scope.t(), String.t()) :: WhiteLabelConfig.t() | nil
```

**Test Assertions**:
- returns white-label config when one exists
- returns nil when no config exists
- requires read access to agency account

### update_white_label_config/3

Updates white-label branding configuration for an agency.

```elixir
@spec update_white_label_config(Scope.t(), String.t(), map()) :: {:ok, WhiteLabelConfig.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Verify user has admin access to the agency account
2. Build WhiteLabelConfig changeset with provided attributes (logo_url, primary_color, secondary_color, subdomain)
3. Validate subdomain format and uniqueness
4. Validate color formats are valid hex colors
5. Upsert white-label config via AgenciesRepository
6. Return ok tuple with saved config, or error with changeset

**Test Assertions**:
- requires admin authorization on agency account
- validates subdomain format and uniqueness
- validates color formats are valid hex
- allows updating logo_url
- creates new config when none exists
- updates existing config when one exists

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Users
- MetricFlow.Infrastructure

## Components

### MetricFlow.Agencies.AutoEnrollmentRule

Ecto schema representing domain-based auto-enrollment configuration for agency accounts. Stores email domain pattern, enabled status, and default access level for auto-enrolled users. Enforces one rule per domain via unique constraint. Provides validations for domain format and access level values.

### MetricFlow.Agencies.WhiteLabelConfig

Ecto schema for agency white-label branding configuration. Stores logo URL, primary and secondary brand colors, and custom subdomain. Enforces unique subdomain constraint. Validates hex color format and subdomain format (lowercase letters, numbers, hyphens).

### MetricFlow.Agencies.AgenciesRepository

Data access layer for agency-specific operations. Provides CRUD for AutoEnrollmentRule and WhiteLabelConfig. Manages agency-client account relationships and access grants. Handles queries for agency team members and client account listings with access metadata. All operations scoped via Scope struct for authorization.

