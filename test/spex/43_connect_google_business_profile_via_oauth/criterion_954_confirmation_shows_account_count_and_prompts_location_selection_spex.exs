defmodule MetricFlowSpex.ConfirmationShowsAccountCountAndPromptsLocationSelectionSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/integrations",
    match_requests_on: [:method, :uri],
    filter_request_headers: ["authorization"]
  ]

  spex "Confirmation shows account count and prompts location selection",
       fail_on_error_logs: false, criterion: 954 do
    scenario "after confirming accounts, the user sees how many connected and a link to continue" do
      given_ :user_logged_in_as_owner

      given_ "a user has confirmed one or more GMB accounts", context do
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

      when_ "the connection completes", context do
        {path, flash} =
          with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
            Application.put_env(:metric_flow, :req_http_options, plug: plug)

            {:ok, view, _html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            view
            |> element("[data-role='account-selection']")
            |> render_submit(%{
              "location_ids" => [
                "accounts/102071280510983396749/locations/10802898290516887436",
                "accounts/102071280510983396749/locations/4842584637917076901"
              ]
            })

            assert_redirect(view)
          end

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, Map.merge(context, %{path: path, flash: flash})}
      end

      then_ "they see confirmation of how many accounts are connected and a prompt to proceed to location selection",
            context do
        assert context.flash["info"] =~ "2 location"

        {:ok, view, _html} = live(context.owner_conn, context.path)
        assert has_element?(view, "a[href*='google_business/accounts']")
        {:ok, context}
      end
    end
  end
end
