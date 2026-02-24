defmodule MetricFlow.DataSync.DataProviders.Behaviour do
  @moduledoc """
  Behaviour contract defining callbacks all data provider implementations must implement.

  Providers implement `fetch_metrics/2` to retrieve data from external APIs using
  OAuth tokens, transform provider-specific data formats to unified metric structures,
  and return an ok tuple with a metrics list or an error tuple with a failure reason.

  Enables separation of concerns between sync orchestration and provider-specific
  API integration. Each implementation is responsible for:

  - Verifying the integration token is not expired
  - Resolving provider-specific configuration (e.g., property_id, customer_id)
  - Building and executing authenticated HTTP requests to the provider API
  - Transforming raw provider responses into unified metric maps
  - Handling HTTP errors and network failures with appropriate error atoms

  ## Unified Metric Format

  Each metric map returned by `fetch_metrics/2` must contain:

  - `:metric_type` - String category for the metric (e.g., "traffic", "revenue")
  - `:metric_name` - String name of the metric (e.g., "sessions", "activeUsers")
  - `:value` - Numeric value (integer or float)
  - `:recorded_at` - `DateTime.t()` timestamp of the observation
  - `:dimensions` - Map with atom keys containing dimension breakdowns
  - `:provider` - Atom matching one of the `Integration.provider` enum values
  """

  alias MetricFlow.Integrations.Integration

  @doc """
  Retrieves metrics from an external provider API using OAuth tokens, transforming
  provider-specific data to unified metric format.

  Implementations must:

  1. Extract access_token from the integration struct
  2. Verify the token is not expired using `Integration.expired?/1`
  3. Resolve provider-specific configuration from options or integration.provider_metadata
  4. Return `{:error, :missing_<config_key>}` if required configuration is absent
  5. Extract date_range from options, defaulting to a provider-appropriate range
  6. Build and execute an authenticated HTTP request to the provider API
  7. Transform the response into a list of unified metric maps
  8. Handle HTTP error codes with appropriate error atoms:
     - 401 -> `:unauthorized`
     - 403 -> `:insufficient_permissions`
     - 404 -> provider-specific not-found atom
     - 400 -> `:bad_request`
  9. Handle network errors and malformed responses with error tuples
  """
  @callback fetch_metrics(Integration.t(), keyword()) ::
              {:ok, list(map())} | {:error, term()}

  @doc """
  Returns the provider atom identifier for this data provider implementation.

  The returned atom must match one of the `Integration.provider` enum values:
  `:github`, `:gitlab`, `:bitbucket`, `:google`, `:google_ads`,
  `:facebook_ads`, `:google_analytics`, `:quickbooks`.
  """
  @callback provider() :: atom()

  @doc """
  Returns the list of OAuth scope strings required for this provider to fetch
  metrics successfully.

  Scopes must be:
  - Non-empty list of binary strings
  - Formatted according to provider OAuth specification
  - Sufficient for read-only metric data access
  - Free of write or administrative scopes unless strictly required
  """
  @callback required_scopes() :: list(String.t())
end
