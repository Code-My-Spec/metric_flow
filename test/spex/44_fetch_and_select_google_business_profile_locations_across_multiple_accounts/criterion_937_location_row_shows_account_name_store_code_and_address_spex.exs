defmodule MetricFlowSpex.LocationRowShowsAccountNameStoreCodeAndAddressSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Location row shows account, name, store code, and address", criterion: 937 do
    scenario "a location's row displays its account, name, store code, and address" do
      given_ :user_logged_in_as_owner

      given_ "a location appears in the merged list", context do
        plug = fn conn ->
          case conn.request_path do
            "/v1/accounts/111/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [
                    %{
                      "name" => "locations/full-detail-loc",
                      "title" => "Full Detail Location",
                      "storeCode" => "STORE-42",
                      "storefrontAddress" => %{
                        "addressLines" => ["123 Main St"],
                        "locality" => "Springfield",
                        "administrativeArea" => "IL",
                        "postalCode" => "62704"
                      }
                    }
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
            "google_business_account_ids" => ["accounts/111"]
          }
        )

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/locations")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user views its row", context do
        html = render(context.view)
        {:ok, Map.put(context, :html, html)}
      end

      then_ "it shows the account name, the location's name, its store code if present, and its address",
            context do
        assert context.html =~ "Full Detail Location"
        assert context.html =~ "Account 111"
        assert context.html =~ "STORE-42"
        assert context.html =~ "Springfield"
        assert has_element?(context.view, "[data-role='location-title']")
        assert has_element?(context.view, "[data-role='location-account-name']")
        assert has_element?(context.view, "[data-role='location-store-code']")
        assert has_element?(context.view, "[data-role='location-address']")

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
