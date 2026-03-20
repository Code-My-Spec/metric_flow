defmodule MetricFlowTest.CassetteFixtures do
  @moduledoc """
  Shared fixtures for cassette-based integration tests.

  Provides pre-built Integration structs for each provider with credentials
  from `.env.test` (loaded via Dotenvy into Application config).

  ## Setup

  Set the following in `.env.test` to enable cassette recording:

      GOOGLE_ADS_TEST_CUSTOMER_ID=1234567890
      GA4_TEST_PROPERTY_ID=properties/123456789
      FACEBOOK_TEST_AD_ACCOUNT_ID=act_123456789
      QUICKBOOKS_TEST_REALM_ID=123456789
      GOOGLE_TEST_ACCESS_TOKEN=ya29...
      GOOGLE_TEST_REFRESH_TOKEN=1//...

  Once cassettes are recorded, these env vars are only needed for re-recording.
  """

  alias MetricFlow.Integrations.Integration

  @cassette_dir "test/cassettes/data_sync"
  @default_date_range {~D[2025-12-01], ~D[2026-03-09]}

  def cassette_dir, do: @cassette_dir
  def default_date_range, do: @default_date_range

  @doc """
  Returns a valid Integration struct for Google Ads with test credentials.
  Returns `nil` if GOOGLE_ADS_TEST_CUSTOMER_ID is not set.
  """
  def google_ads_integration do
    case test_cred(:google_ads_customer_id) do
      nil -> nil
      customer_id ->
        metadata = %{"customer_id" => customer_id}

        metadata =
          case test_cred(:google_ads_login_customer_id) do
            nil -> metadata
            login_id -> Map.put(metadata, "login_customer_id", login_id)
          end

        build_integration(:google_ads, metadata)
    end
  end

  @doc """
  Returns a valid Integration struct for Google Analytics (GA4) with test credentials.
  Returns `nil` if GA4_TEST_PROPERTY_ID is not set.
  """
  def google_analytics_integration do
    case test_cred(:ga4_property_id) do
      nil -> nil
      property_id ->
        build_integration(:google_analytics, %{
          "property_id" => property_id
        })
    end
  end

  @doc """
  Returns a valid Integration struct for Facebook Ads with test credentials.
  Returns `nil` if FACEBOOK_TEST_AD_ACCOUNT_ID is not set.
  """
  def facebook_ads_integration do
    case test_cred(:facebook_ad_account_id) do
      nil -> nil
      ad_account_id ->
        build_integration(:facebook_ads, %{
          "ad_account_id" => ad_account_id
        })
    end
  end

  @doc """
  Returns a valid Integration struct for QuickBooks with test credentials.
  Returns `nil` if QUICKBOOKS_TEST_REALM_ID is not set.
  """
  def quickbooks_integration do
    case test_cred(:quickbooks_realm_id) do
      nil -> nil
      realm_id ->
        build_integration(:quickbooks, %{
          "realm_id" => realm_id,
          "income_account_id" => test_cred(:quickbooks_income_account_id) || "1"
        })
    end
  end

  @doc """
  Standard ReqCassette options for data provider tests.
  Filters sensitive headers to avoid leaking tokens into cassette files.
  """
  def cassette_opts(_name) do
    [
      cassette_dir: @cassette_dir,
      match_requests_on: [:method, :uri],
      filter_request_headers: ["authorization", "developer-token"],
      filter_query_params: ["access_token"]
    ]
  end

  defp test_cred(key) do
    creds = Application.get_env(:metric_flow, :test_credentials, [])
    Keyword.get(creds, key)
  end

  defp build_integration(provider, metadata) do
    {access_token, refresh_token} = tokens_for(provider)

    struct!(Integration,
      id: 1,
      provider: provider,
      access_token: access_token,
      refresh_token: refresh_token,
      expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
      granted_scopes: [],
      provider_metadata: metadata,
      user_id: 1
    )
  end

  defp tokens_for(provider) when provider in [:google_ads, :google_analytics] do
    {
      test_cred(:google_access_token) || "cassette-token",
      test_cred(:google_refresh_token) || "cassette-refresh"
    }
  end

  defp tokens_for(:facebook_ads) do
    {
      test_cred(:facebook_access_token) || "cassette-token",
      "cassette-refresh"
    }
  end

  defp tokens_for(:quickbooks) do
    {
      test_cred(:quickbooks_access_token) || "cassette-token",
      "cassette-refresh"
    }
  end

  defp tokens_for(_provider) do
    {"cassette-token", "cassette-refresh"}
  end
end
