defmodule MetricFlowSpex.Criterion4847EachSelectedAccountDisplayedWithNameAndIdSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  import MetricFlowSpex.SharedGivens

  spex "Each selected account is displayed with its account name and account ID",
       fail_on_error_logs: false, criterion: 387 do
    scenario "Google Business account selection page shows account names and IDs" do
      given_ :user_logged_in_as_owner

      given_ "user has a connected google_business integration", context do
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        creds = Application.get_env(:metric_flow, :test_credentials, [])
        access_token = Keyword.get(creds, :google_access_token, "cassette-token")
        refresh_token = Keyword.get(creds, :google_refresh_token, "cassette-refresh")

        Application.put_env(:metric_flow, :req_http_options,
          plug: fn conn -> Plug.Conn.send_resp(conn, 404, "") end
        )

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

      then_ "each account entry shows its account name via data-role attribute", context do
        capture_log(fn ->
          {:ok, view, _html} =
            live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

          assert has_element?(view, "[data-role='account-name']")
        end)

        {:ok, context}
      end

      then_ "each account entry shows its account ID via data-role attribute", context do
        capture_log(fn ->
          {:ok, view, _html} =
            live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

          assert has_element?(view, "[data-role='account-id']")
        end)

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
