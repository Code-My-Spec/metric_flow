defmodule MetricFlowSpex.DeletedOrInaccessibleLocationIsFlaggedRatherThanSilentlyDroppedSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Deleted or inaccessible location is flagged rather than silently dropped", criterion: 940 do
    scenario "a previously synced location missing from the current fetch is flagged, not dropped" do
      given_ :user_logged_in_as_owner

      given_ "a previously synced location has since been deleted or had access revoked", context do
        plug = fn conn ->
          case conn.request_path do
            "/v1/accounts/111/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/still-here", "title" => "Still Here Location"}]
                })
              )

            _ ->
              Plug.Conn.send_resp(conn, 404, "")
          end
        end

        Application.put_env(:metric_flow, :req_http_options, plug: plug)

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{
            "google_business_account_ids" => ["accounts/111"],
            "included_locations" => ["accounts/111/locations/now-gone"]
          }
        )

        {:ok, context}
      end

      when_ "the system next fetches locations", context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "that location is flagged in the UI rather than silently disappearing from the sync configuration",
            context do
        assert has_element?(context.view, "[data-role='missing-location']")
        assert has_element?(context.view, "[data-role='location-unavailable']")
        assert context.html =~ "accounts/111/locations/now-gone"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
