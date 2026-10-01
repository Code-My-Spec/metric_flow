defmodule MetricFlowSpex.SelectedAccountShowsItsNameAndIdSpex do
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

  spex "Selected account shows its name and ID", fail_on_error_logs: false, criterion: 947 do
    scenario "a selected GMB account's row in the list shows both its name and account ID" do
      given_ :user_logged_in_as_owner

      given_ "a user has selected a GMB account", context do
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

      then_ "viewing it in the selection list shows that account's name and account ID", context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, _html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            assert has_element?(
                     view,
                     "[data-role='location-account-name']",
                     "102071280510983396749"
                   )
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        {:ok, context}
      end
    end
  end
end
