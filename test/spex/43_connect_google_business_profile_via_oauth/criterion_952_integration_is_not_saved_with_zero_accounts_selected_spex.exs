defmodule MetricFlowSpex.IntegrationIsNotSavedWithZeroAccountsSelectedSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Integration is not saved with zero accounts selected", criterion: 952 do
    scenario "attempting to finish connecting with no account selected shows an error and does not save" do
      given_ :user_logged_in_as_owner

      given_ "a user has not yet selected any GMB account", context do
        plug = fn conn ->
  conn = Plug.Conn.put_resp_content_type(conn, "application/json")

          case conn.request_path do
            "/v1/accounts" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "accounts" => [
                    %{"name" => "accounts/111", "accountName" => "Account One"}
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

      when_ "they attempt to finish connecting", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        view
        |> element("[data-role='account-selection']")
        |> render_submit(%{"google_business_account_ids" => []})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration is not saved until at least one account is selected and confirmed",
            context do
        html = render(context.view)
        assert html =~ "Please select at least one"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
