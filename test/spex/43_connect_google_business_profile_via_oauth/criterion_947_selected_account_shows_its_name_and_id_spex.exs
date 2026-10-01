defmodule MetricFlowSpex.SelectedAccountShowsItsNameAndIdSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Selected account shows its name and ID", criterion: 947 do
    scenario "a selected GMB account's row in the list shows both its name and account ID" do
      given_ :user_logged_in_as_owner

      given_ "a user has selected a GMB account", context do
        plug = fn conn ->
  conn = Plug.Conn.put_resp_content_type(conn, "application/json")

          case conn.request_path do
            "/v1/accounts" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "accounts" => [
                    %{"name" => "accounts/102071280510983396749", "accountName" => "John Davenport"}
                  ]
                })
              )

            _ ->
              Plug.Conn.send_resp(conn, 404, "")
          end
        end

        Application.put_env(:metric_flow, :req_http_options, plug: plug)

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{
            "google_business_account_ids" => ["accounts/102071280510983396749"]
          }
        )

        {:ok, context}
      end

      then_ "viewing it in the selection list shows that account's name and account ID", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        assert has_element?(view, "[data-role='account-name']", "John Davenport")
        assert has_element?(view, "[data-role='account-id']", "102071280510983396749")

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
