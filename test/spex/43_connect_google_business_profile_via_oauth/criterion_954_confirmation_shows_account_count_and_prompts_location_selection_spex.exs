defmodule MetricFlowSpex.ConfirmationShowsAccountCountAndPromptsLocationSelectionSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Confirmation shows account count and prompts location selection", criterion: 954 do
    scenario "after confirming accounts, the user sees how many connected and is sent to pick locations" do
      given_ :user_logged_in_as_owner

      given_ "a user is confirming one or more GMB accounts", context do
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

        {:ok, context}
      end

      when_ "the account selection completes", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        view
        |> element("[data-role='account-selection']")
        |> render_submit(%{"google_business_account_ids" => ["accounts/111", "accounts/222"]})

        {path, flash} = assert_redirect(view)
        {:ok, Map.merge(context, %{path: path, flash: flash})}
      end

      then_ "they see confirmation of how many accounts are connected and are prompted to select locations",
            context do
        assert context.flash["info"] =~ "2 business account"
        assert context.path =~ "/app/integrations/connect/google_business/locations"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
