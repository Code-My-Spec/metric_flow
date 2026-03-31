defmodule MetricFlowSpex.Criterion4853UserSeesConfirmationOfConnectedGMBAccountsSpex do
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

  spex "User sees confirmation showing how many GMB accounts are connected and a prompt to proceed to location selection",
       fail_on_error_logs: false do
    scenario "connected Google Business detail page shows connected status and a link to select locations" do
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

      then_ "the detail page shows Connected status", context do
        {:ok, _view, html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert html =~ "Connected"
        :ok
      end

      then_ "the detail page shows a link to the location selection page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations/connect/google_business")
        assert has_element?(view, "a[href*='google_business/accounts']")
        :ok
      end
    end

    scenario "saving a location selection shows a flash message referencing the saved locations" do
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

      then_ "submitting two location IDs redirects with a flash message mentioning location count",
            context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, _html} =
              live(context.owner_conn, "/integrations/connect/google_business/accounts")

            view
            |> form("[data-role='account-selection']")
            |> render_submit(%{
              "location_ids" => [
                "accounts/102071280510983396749/locations/10802898290516887436",
                "accounts/102071280510983396749/locations/4842584637917076901"
              ]
            })

            {path, flash} = assert_redirect(view)
            assert path =~ "/integrations/connect/google_business"
            assert flash["info"] =~ "location"
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
