defmodule MetricFlowSpex.UserRemovesAnAccountLaterWithoutReAuthenticatingSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/integrations",
    match_requests_on: [:method, :uri],
    filter_request_headers: ["authorization"]
  ]

  spex "User removes an account later without re-authenticating", fail_on_error_logs: false,
       criterion: 951 do
    scenario "removing one of two previously selected locations does not require OAuth again" do
      given_ :user_logged_in_as_owner

      given_ "a user has multiple GMB accounts connected", context do
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
              "accounts/102071280510983396749/locations/10802898290516887436",
              "accounts/102071280510983396749/locations/4842584637917076901"
            ]
          }
        })

        {:ok, context}
      end

      when_ "they return to remove one of them", context do
        view =
          with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
            Application.put_env(:metric_flow, :req_http_options, plug: plug)

            {:ok, view, html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            refute html =~ "/app/integrations/oauth/google_business"

            view
            |> element("[data-role='account-selection']")
            |> render_submit(%{
              "location_ids" => [
                "accounts/102071280510983396749/locations/10802898290516887436"
              ]
            })

            view
          end

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can do so without going through OAuth again", context do
        {path, flash} = assert_redirect(context.view)
        refute path =~ "oauth"
        assert flash["info"] =~ "1 location"
        {:ok, context}
      end
    end
  end
end
