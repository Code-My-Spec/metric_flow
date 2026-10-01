defmodule MetricFlowSpex.AllSelectedAccountsAreSavedTogetherSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "All selected accounts are saved together", criterion: 948 do
    scenario "saving the integration persists every selected account, not just the first" do
      given_ :user_logged_in_as_owner

      given_ "a user selected multiple GMB accounts", context do
        plug = fn conn ->
          case conn.request_path do
            "/v1/accounts/111/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/loc-a", "title" => "Location A"}]
                })
              )

            "/v1/accounts/222/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/loc-b", "title" => "Location B"}]
                })
              )

            _ ->
              Plug.Conn.send_resp(conn, 404, "")
          end
        end

        Application.put_env(:metric_flow, :req_http_options, plug: plug)

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{
            "google_business_account_ids" => ["accounts/111", "accounts/222"]
          }
        )

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        view
        |> element("[data-role='account-selection']")
        |> render_submit(%{
          "location_ids" => ["accounts/111/locations/loc-a", "accounts/222/locations/loc-b"]
        })

        {_path, _flash} = assert_redirect(view)
        {:ok, context}
      end

      when_ "the integration is saved", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "all selected accounts are saved together, not just the first one", context do
        assert has_element?(
                 context.view,
                 "input[type='checkbox'][value='accounts/111/locations/loc-a'][checked]"
               )

        assert has_element?(
                 context.view,
                 "input[type='checkbox'][value='accounts/222/locations/loc-b'][checked]"
               )

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
