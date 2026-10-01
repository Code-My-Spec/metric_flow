defmodule MetricFlowSpex.LocationsFromMultipleAccountsMergeIntoOneListSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Locations from multiple accounts merge into one list", criterion: 935 do
    scenario "locations fetched from two accounts appear together in a single flat list" do
      given_ :user_logged_in_as_owner

      given_ "locations have been fetched from two connected accounts", context do
        plug = fn conn ->
          case conn.request_path do
            "/v1/accounts/111/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/first-acct-loc", "title" => "First Account Location"}]
                })
              )

            "/v1/accounts/222/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/second-acct-loc", "title" => "Second Account Location"}]
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

        {:ok, context}
      end

      when_ "the user views the location list", context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "locations from both accounts appear together in a single flat list", context do
        assert context.html =~ "First Account Location"
        assert context.html =~ "Second Account Location"
        assert has_element?(context.view, "[data-role='account-list']")
        refute has_element?(context.view, "[data-role='account-tab']")

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
