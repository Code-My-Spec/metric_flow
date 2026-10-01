defmodule MetricFlowSpex.UserUpdatesLocationSelectionLaterWithoutReAuthenticatingSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User updates location selection later without re-authenticating", criterion: 939 do
    scenario "changing a previously saved location selection takes effect without reconnecting" do
      given_ :user_logged_in_as_owner

      given_ "a user previously selected locations to sync", context do
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
            "google_business_account_ids" => ["accounts/111"],
            "included_locations" => ["accounts/111/locations/loc-one"]
          }
        )

        {:ok, context}
      end

      when_ "they return later and change which locations are included", context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        refute html =~ "/app/integrations/oauth/google_business"

        view
        |> element("[data-role='account-selection']")
        |> render_submit(%{"location_ids" => ["accounts/111/locations/loc-two"]})

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the change takes effect without requiring them to reconnect or re-authenticate",
            context do
        {path, flash} = assert_redirect(context.view)
        refute path =~ "oauth"
        assert flash["info"] =~ "1 location"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
