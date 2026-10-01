defmodule MetricFlowSpex.UserSelectsMultipleGmbAccountsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects multiple GMB accounts", criterion: 946 do
    scenario "selecting locations from two GBP accounts accepts both as part of the same connection" do
      given_ :user_logged_in_as_owner

      given_ "a business has locations spread across two GBP accounts", context do
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

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects both accounts", context do
        context.view
        |> element("[data-role='account-selection']")
        |> render_submit(%{
          "location_ids" => ["accounts/111/locations/loc-a", "accounts/222/locations/loc-b"]
        })

        {:ok, context}
      end

      then_ "both are accepted as part of the same connection", context do
        {_path, flash} = assert_redirect(context.view)
        assert flash["info"] =~ "2 location"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
