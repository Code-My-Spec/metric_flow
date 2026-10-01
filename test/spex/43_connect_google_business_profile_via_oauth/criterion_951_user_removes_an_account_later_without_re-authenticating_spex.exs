defmodule MetricFlowSpex.UserRemovesAnAccountLaterWithoutReAuthenticatingSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User removes an account later without re-authenticating", criterion: 951 do
    scenario "removing one of two previously selected accounts does not require OAuth again" do
      given_ :user_logged_in_as_owner

      given_ "a user has two GMB accounts connected", context do
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
          provider_metadata: %{"google_business_account_ids" => ["accounts/111", "accounts/222"]}
        )

        {:ok, context}
      end

      when_ "they return to remove one of them", context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        refute html =~ "/app/integrations/oauth/google_business"

        view
        |> element("[data-role='account-selection']")
        |> render_submit(%{"google_business_account_ids" => ["accounts/111"]})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can do so without going through OAuth again", context do
        {path, flash} = assert_redirect(context.view)
        refute path =~ "oauth"
        assert flash["info"] =~ "1 business account"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
