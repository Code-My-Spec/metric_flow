defmodule MetricFlowSpex.IntegrationIsNotSavedWithZeroAccountsSelectedSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ReqCassette

  import MetricFlowSpex.SharedGivens

  @cassette_opts [
    cassette_dir: "test/cassettes/integrations",
    match_requests_on: [:method, :uri],
    filter_request_headers: ["authorization"]
  ]

  spex "Integration is not saved with zero accounts selected", fail_on_error_logs: false,
       criterion: 952 do
    scenario "attempting to finish connecting with no location selected shows an error and does not save" do
      given_ :user_logged_in_as_owner

      given_ "a user has not selected any GMB account", context do
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

      when_ "they attempt to finish connecting", context do
        view =
          with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
            Application.put_env(:metric_flow, :req_http_options, plug: plug)

            {:ok, view, _html} =
              live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

            view
            |> element("[data-role='account-selection']")
            |> render_submit(%{"location_ids" => []})

            view
          end

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration is not saved until at least one account is selected and confirmed",
            context do
        html = render(context.view)
        assert html =~ "Please select at least one"
        {:ok, context}
      end
    end
  end
end
