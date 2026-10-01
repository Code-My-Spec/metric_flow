defmodule MetricFlowSpex.SameLocationIdUnderDifferentAccountsRemainsDistinguishableSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Same location ID under different accounts remains distinguishable", criterion: 938 do
    scenario "two accounts each with a location sharing the same raw ID stay distinguishable when both are selected" do
      given_ :user_logged_in_as_owner

      given_ "two connected accounts each have a location sharing the same underlying location ID",
             context do
        plug = fn conn ->
          case conn.request_path do
            "/v1/accounts/111/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/shared-id", "title" => "Shared Name — Account 111"}]
                })
              )

            "/v1/accounts/222/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/shared-id", "title" => "Shared Name — Account 222"}]
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

      when_ "they select both for syncing", context do
        assert has_element?(
                 context.view,
                 "input[type='checkbox'][value='accounts/111/locations/shared-id']"
               )

        assert has_element?(
                 context.view,
                 "input[type='checkbox'][value='accounts/222/locations/shared-id']"
               )

        context.view
        |> element("[data-role='account-selection']")
        |> render_submit(%{
          "location_ids" => [
            "accounts/111/locations/shared-id",
            "accounts/222/locations/shared-id"
          ]
        })

        {:ok, context}
      end

      then_ "the stored configuration keeps them distinguishable by which account each belongs to",
            context do
        {_path, flash} = assert_redirect(context.view)
        assert flash["info"] =~ "2 location"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
