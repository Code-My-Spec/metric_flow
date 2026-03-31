defmodule MetricFlowSpex.Criterion4851IntegrationSavedOnlyAfterAccountSelectedAndConfirmedSpex do
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

  spex "Integration is saved only after at least one account is selected and confirmed",
       fail_on_error_logs: false do
    scenario "submitting with no selections shows a validation error and stays on the page" do
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

      then_ "submitting with empty location_ids shows an error requiring at least one selection",
            context do
        with_cassette "gbp_locations_list", @cassette_opts, fn plug ->
          Application.put_env(:metric_flow, :req_http_options, plug: plug)

          capture_log(fn ->
            {:ok, view, _html} =
              live(context.owner_conn, "/integrations/connect/google_business/accounts")

            view
            |> form("[data-role='account-selection']")
            |> render_submit(%{"location_ids" => []})

            html = render(view)
            assert html =~ "Please select at least one"
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end

    scenario "submitting with at least one location selected saves and redirects" do
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

      then_ "submitting with a valid location ID saves and redirects to the detail page",
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
                "accounts/102071280510983396749/locations/10802898290516887436"
              ]
            })

            {path, _flash} = assert_redirect(view)
            assert path =~ "/integrations/connect/google_business"
          end)

          Application.delete_env(:metric_flow, :req_http_options)
        end

        :ok
      end
    end
  end
end
