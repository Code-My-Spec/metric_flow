defmodule MetricFlowSpex.UserSelectsMultipleGmbAccountsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects multiple GMB accounts", criterion: 946 do
    scenario "selecting two GBP accounts accepts both as part of the same connection" do
      given_ :user_logged_in_as_owner

      given_ "a business has access to two GBP accounts", context do
        plug = fn conn ->
  conn = Plug.Conn.put_resp_content_type(conn, "application/json")

          case conn.request_path do
            "/v1/accounts" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "accounts" => [
                    %{"name" => "accounts/111", "accountName" => "Account One"},
                    %{"name" => "accounts/222", "accountName" => "Account Two"}
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

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects both accounts", context do
        context.view
        |> element("[data-role='account-selection']")
        |> render_submit(%{"google_business_account_ids" => ["accounts/111", "accounts/222"]})

        {:ok, context}
      end

      then_ "both are accepted as part of the same connection", context do
        {_path, flash} = assert_redirect(context.view)
        assert flash["info"] =~ "2 business account"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
