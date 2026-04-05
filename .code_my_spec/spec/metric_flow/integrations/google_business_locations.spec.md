# MetricFlow.Integrations.GoogleBusinessLocations

Fetches locations across all Google Business Profile accounts. Uses the My Business Business Information API v1 to list locations for each configured account ID. Handles pagination via `nextPageToken` and merges results into a flat list. When no account IDs are stored in provider_metadata, falls back to fetching accounts from the Account Management API. Accepts an `:http_plug` option for dependency injection during tests.

## Functions

### list_locations/2

Lists all locations across all configured GBP account IDs.

```elixir
@spec list_locations(Integration.t(), keyword()) ::
        {:ok, list(map())} | {:error, term()}
```

**Process**:
1. Read google_business_account_ids from integration's provider_metadata
2. If no account IDs stored, fetch them from the Account Management API via fetch_accounts/2
3. If fetched accounts are empty, return {:error, :no_accounts_configured}
4. For each account ID, fetch locations from the Business Information API with pagination
5. Merge all locations into a flat list
6. Each location map has :id, :name, :account, :store_code, :address, :website, and :category keys
7. Return {:ok, locations}

**Test Assertions**:
- returns {:ok, locations} with a list of location maps on successful API response
- each returned location map has :id, :name, :account, :store_code, :address, :website, and :category keys
- handles pagination via nextPageToken
- returns {:error, :no_accounts_configured} when no account IDs found
- returns {:error, :unauthorized} on 401 response
- returns {:error, :api_disabled} on 403 response
- falls back to fetching accounts when provider_metadata has no account IDs
- accepts :http_plug option for test injection

### fetch_accounts/2

Fetches the user's GBP account IDs from the Account Management API.

```elixir
@spec fetch_accounts(Integration.t(), keyword()) :: {:ok, list(String.t())} | {:error, term()}
```

**Process**:
1. Build request to the Account Management API accounts endpoint
2. Use Bearer token from integration.access_token
3. On 200, extract account names from response
4. On 401, return {:error, :unauthorized}
5. On 403, return {:error, :api_disabled}
6. On other status, return {:error, :bad_request}
7. On exception, return {:error, {:network_error, message}}

**Test Assertions**:
- returns {:ok, account_ids} with list of account name strings on success
- returns {:ok, []} when response has no accounts
- returns {:error, :unauthorized} on 401 response
- returns {:error, :api_disabled} on 403 response
- returns {:error, :bad_request} on unexpected status
- returns {:error, {:network_error, message}} on exception
- accepts :http_plug option for test injection

## Dependencies

- MetricFlow.Integrations.Integration
- Logger
- Req
