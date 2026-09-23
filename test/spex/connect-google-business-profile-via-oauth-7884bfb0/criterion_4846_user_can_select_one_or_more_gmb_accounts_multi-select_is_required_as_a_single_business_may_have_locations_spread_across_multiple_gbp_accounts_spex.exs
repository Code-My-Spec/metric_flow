defmodule MetricFlowSpex.Criterion4846UserCanSelectMultipleGMBAccountsSpex do
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

  spex "User can select ONE OR MORE GMB accounts — multi-select required",
       fail_on_error_logs: false do
    scenario "Google Business account selection page uses checkboxes, not radio buttons" do
      given_ :user_logged_in_as_owner

      given_ "user has a connected google_business integration", context do
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

      then_ "the account selection page uses checkboxes for multi-select", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, _html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            assert has_element?(view, "input[type='checkbox'][name='location_ids[]']")
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end

      then_ "no radio buttons are used on the Google Business account selection page", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, _view, html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            refute html =~ "type=\"radio\""
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
