defmodule MetricFlowSpex.Criterion4845AfterAuthUserSeesGBPAccountListSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/integrations",
    match_requests_on: [:method, :uri],
    filter_request_headers: ["authorization"]
  ]

  spex "After successful authentication, user sees a list of Google Business Profile locations",
       fail_on_error_logs: false, criterion: 385 do
    scenario "connected user sees real locations fetched from the GBP API" do
      given_ :user_logged_in_as_owner

      given_ "user has a connected google_business integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)

        # Use real token from .env.test for cassette recording; on replay the cassette is used
        creds = Application.get_env(:metric_flow, :test_credentials, [])
        access_token = Keyword.get(creds, :google_access_token, "cassette-token")
        refresh_token = Keyword.get(creds, :google_refresh_token, "cassette-refresh")

        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_business,
          access_token: access_token,
          refresh_token: refresh_token,
          granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
          provider_metadata: %{
            "email" => context.owner_email,
            "google_business_account_ids" => ["accounts/102071280510983396749"]
          }
        })

        {:ok, context}
      end

      then_ "the user first selects which GMB accounts to authorize, then sees real locations with checkboxes",
            context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, accounts_view, accounts_html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            assert accounts_html =~ "data-role=\"account-list\""
            assert has_element?(accounts_view, "input[type='checkbox'][name='google_business_account_ids[]']")
            assert accounts_html =~ "Select Accounts"

            accounts_view
            |> form("[data-role='account-selection']")
            |> render_submit(%{"google_business_account_ids" => ["accounts/102071280510983396749"]})

            {:ok, locations_view, locations_html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/locations")

            # Real location list rendered (not manual entry fallback)
            assert locations_html =~ "data-role=\"location-title\""
            assert locations_html =~ "data-role=\"location-account-name\""

            # Multi-select checkboxes
            assert has_element?(locations_view, "input[type='checkbox'][name='location_ids[]']")

            # Save button present
            assert has_element?(locations_view, "[data-role='save-selection']")
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        {:ok, context}
      end
    end
  end
end
