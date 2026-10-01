defmodule MetricFlowSpex.UserSeesAllAccessibleGbpAccountsAfterAuthenticatingSpex do
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

  spex "User sees all accessible GBP accounts after authenticating", fail_on_error_logs: false,
       criterion: 945 do
    scenario "the account list shows every Google Business Profile account the user has access to" do
      given_ :user_logged_in_as_owner

      given_ "a user has completed Google authentication", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
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

      then_ "the account list, once loaded, shows every Google Business Profile account they have access to",
            context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            assert has_element?(view, "[data-role='account-list']")
            assert has_element?(view, "[data-role='location-account-name']")
            assert html =~ "102071280510983396749"
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        {:ok, context}
      end
    end
  end
end
