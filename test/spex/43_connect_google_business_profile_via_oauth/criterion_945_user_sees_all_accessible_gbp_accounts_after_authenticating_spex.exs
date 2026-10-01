defmodule MetricFlowSpex.UserSeesAllAccessibleGbpAccountsAfterAuthenticatingSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User sees all accessible GBP accounts after authenticating", criterion: 945 do
    scenario "the account list shows every Google Business Profile account the user has access to" do
      given_ :user_logged_in_as_owner

      given_ "a user has completed Google authentication and has access to two GBP accounts",
             context do
        plug = fn conn ->
  conn = Plug.Conn.put_resp_content_type(conn, "application/json")

          case conn.request_path do
            "/v1/accounts" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "accounts" => [
                    %{"name" => "accounts/111", "accountName" => "John Davenport"},
                    %{"name" => "accounts/222", "accountName" => "Albany Firewood"}
                  ]
                })
              )

            _ ->
              Plug.Conn.send_resp(conn, 404, "")
          end
        end

        Application.put_env(:metric_flow, :req_http_options, plug: plug)

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{}
        )

        {:ok, context}
      end

      then_ "the account list, once loaded, shows every Google Business Profile account they have access to",
            context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        assert has_element?(view, "[data-role='account-list']")
        assert html =~ "John Davenport"
        assert html =~ "Albany Firewood"
        assert html =~ "accounts/111"
        assert html =~ "accounts/222"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
