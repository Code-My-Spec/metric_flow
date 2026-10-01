defmodule MetricFlowSpex.AllLocationsAreFetchedAcrossAccountsIncludingPaginatedResultsSpex do
  use MetricFlowSpex.Case, async: false
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "All locations are fetched across accounts, including paginated results", criterion: 934 do
    scenario "locations from a paginated account and a single-page account both appear" do
      given_ :user_logged_in_as_owner

      given_ "a customer has two connected GBP accounts, one with enough locations to require multiple pages of API results",
             context do
        plug = fn conn ->
          %{query_params: query} = Plug.Conn.fetch_query_params(conn)

          case conn.request_path do
            "/v1/accounts/111/locations" ->
              case query["pageToken"] do
                nil ->
                  Plug.Conn.send_resp(
                    conn,
                    200,
                    Jason.encode!(%{
                      "locations" => [%{"name" => "locations/page1-loc", "title" => "Page One Location"}],
                      "nextPageToken" => "page-2-token"
                    })
                  )

                "page-2-token" ->
                  Plug.Conn.send_resp(
                    conn,
                    200,
                    Jason.encode!(%{
                      "locations" => [%{"name" => "locations/page2-loc", "title" => "Page Two Location"}]
                    })
                  )
              end

            "/v1/accounts/222/locations" ->
              Plug.Conn.send_resp(
                conn,
                200,
                Jason.encode!(%{
                  "locations" => [%{"name" => "locations/single-loc", "title" => "Single Account Location"}]
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

      when_ "the system fetches locations", context do
        {:ok, _view, html} =
          live(context.owner_conn, "/app/integrations/connect/google_business/accounts")

        {:ok, Map.put(context, :html, html)}
      end

      then_ "it retrieves every location from both accounts, following pagination until complete",
            context do
        assert context.html =~ "Page One Location"
        assert context.html =~ "Page Two Location"
        assert context.html =~ "Single Account Location"

        Application.delete_env(:metric_flow, :req_http_options)
        {:ok, context}
      end
    end
  end
end
