defmodule MetricFlowSpex.Criterion4850UserCanReturnToSettingsWithoutReauthSpex do
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

  spex "User can return to settings to add/remove accounts without re-authenticating",
       fail_on_error_logs: false do
    scenario "previously connected user can revisit the accounts selection page without new OAuth" do
      given_ :user_logged_in_as_owner

      given_ "user has a connected google_business integration with saved locations", context do
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
            "google_business_account_ids" => ["accounts/102071280510983396749"],
            "included_locations" => [
              "accounts/102071280510983396749/locations/10802898290516887436"
            ]
          }
        })

        {:ok, context}
      end

      then_ "visiting the accounts page a second time loads without OAuth redirect", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, _view, html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            assert html =~ "Select Accounts"
            assert html =~ "data-role=\"account-list\""
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end

      then_ "the accounts page shows checkboxes so the user can modify their selection",
            context do
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
    end

    scenario "the detail page links to the accounts sub-path without triggering OAuth" do
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

      then_ "the detail page contains a link to the google_business accounts path", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/connect/google_business")
        assert has_element?(view, "a[href*='google_business/accounts']")
        :ok
      end
    end
  end
end
