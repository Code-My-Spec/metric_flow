defmodule MetricFlowSpex.UserSelectsLocationsToIncludeInSyncingSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User selects locations to include in syncing", criterion: 936 do
    scenario "selecting a subset of the merged location list saves it for syncing" do
      given_ :user_logged_in_as_owner

      given_ "a user viewing the full merged location list", context do
        plug = fn conn ->
          case conn.request_path do
            "/v1/accounts/111/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [
                    %{"name" => "locations/loc-one", "title" => "Location One"},
                    %{"name" => "locations/loc-two", "title" => "Location Two"}
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

      when_ "they select a subset of locations", context do
        context.view
        |> element("[data-role='account-selection']")
        |> render_submit(%{"location_ids" => ["accounts/111/locations/loc-one"]})

        {:ok, context}
      end

      then_ "those locations are set to be included in syncing", context do
        {path, flash} = assert_redirect(context.view)
        assert path =~ "/app/integrations/connect/google_business"
        assert flash["info"] =~ "1 location"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
