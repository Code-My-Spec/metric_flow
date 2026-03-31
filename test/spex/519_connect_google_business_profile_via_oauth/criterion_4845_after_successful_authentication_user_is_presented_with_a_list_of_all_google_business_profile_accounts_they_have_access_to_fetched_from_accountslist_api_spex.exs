defmodule MetricFlowSpex.Criterion4845AfterAuthUserSeesGBPAccountListSpex do
  use SexySpex
  use MetricFlowTest.ConnCase, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog
  import ReqCassette

  import_givens MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/integrations",
    match_requests_on: [:method, :uri],
    filter_request_headers: ["authorization"]
  ]

  spex "After successful authentication, user sees a list of Google Business Profile locations",
       fail_on_error_logs: false do
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

      then_ "the accounts page shows real locations with checkboxes", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, html} =
              live(context.owner_conn, "/integrations/connect/google_business/accounts")

            # Real account list rendered (not manual entry fallback)
            assert html =~ "data-role=\"account-list\""
            assert html =~ "data-role=\"location-title\""
            assert html =~ "data-role=\"location-account-name\""

            # Multi-select checkboxes
            assert has_element?(view, "input[type='checkbox'][name='location_ids[]']")

            # Heading
            assert html =~ "Select Accounts"

            # Save button present
            assert has_element?(view, "[data-role='save-selection']")
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
