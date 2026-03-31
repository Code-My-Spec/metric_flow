defmodule MetricFlowSpex.Criterion4849LegacySingularFieldMigrationShowsPreselectedAccountSpex do
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

  spex "Legacy singular field migration shows pre-selected account",
       fail_on_error_logs: false do
    scenario "user with legacy singular google_business_account_id can access the accounts page" do
      given_ :user_logged_in_as_owner

      given_ "user has a google_business integration with legacy singular account id", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        creds = Application.get_env(:metric_flow, :test_credentials, [])
        access_token = Keyword.get(creds, :google_access_token, "cassette-token")
        refresh_token = Keyword.get(creds, :google_refresh_token, "cassette-refresh")

        # Legacy: singular google_business_account_id (not the plural array form)
        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :google_business,
          access_token: access_token,
          refresh_token: refresh_token,
          granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
          provider_metadata: %{
            "email" => context.owner_email,
            "google_business_account_id" => "accounts/102071280510983396749"
          }
        })

        {:ok, context}
      end

      then_ "the accounts page loads without crashing for legacy data", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, _view, html} =
              live(context.owner_conn, "/integrations/connect/google_business/accounts")

            assert html =~ "Select Accounts"
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end

      then_ "the save selection button is present so the user can confirm a selection", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, _html} =
              live(context.owner_conn, "/integrations/connect/google_business/accounts")

            assert has_element?(view, "[data-role='save-selection']")
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
