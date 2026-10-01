defmodule MetricFlowSpex.LegacySingleAccountConnectionIsPreSelectedDuringMigrationSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/integrations",
    match_requests_on: [:method, :uri],
    filter_request_headers: ["authorization"]
  ]

  spex "Legacy single-account connection is pre-selected during migration",
       fail_on_error_logs: false, criterion: 949 do
    scenario "a user with a legacy singular account connection sees it pre-selected on revisit" do
      given_ :user_logged_in_as_owner

      given_ "a user previously connected a single legacy GMB account", context do
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
            "google_business_account_id" => "accounts/102071280510983396749"
          }
        })

        {:ok, context}
      end

      when_ "they revisit the GBP integration settings", context do
        {view, html} =
          with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
            Application.put_env(:metric_flow, :req_http_options, plug: plug)

            {:ok, view, html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            {view, html}
          end

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "that account appears pre-selected and they are prompted to confirm before proceeding",
            context do
        assert has_element?(context.view, "input[type='checkbox'][checked]")
        {:ok, context}
      end
    end
  end
end
