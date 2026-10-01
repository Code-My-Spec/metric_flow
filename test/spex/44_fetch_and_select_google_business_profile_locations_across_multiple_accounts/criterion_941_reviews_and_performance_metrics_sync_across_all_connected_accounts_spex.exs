defmodule MetricFlowSpex.ReviewsAndPerformanceMetricsSyncAcrossAllConnectedAccountsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Reviews and performance metrics sync across all connected accounts", criterion: 941 do
    scenario "a sync requests both performance and review data for locations from every connected account" do
      given_ :user_logged_in_as_owner

      given_ "a customer has locations across multiple connected GBP accounts", context do
        {:ok, agent} = Agent.start_link(fn -> MapSet.new() end)

        plug = fn conn ->
          Agent.update(agent, &MapSet.put(&1, conn.request_path))

          conn = Plug.Conn.put_resp_content_type(conn, "application/json")

          cond do
            String.contains?(conn.request_path, ":fetchMultiDailyMetricsTimeSeries") ->
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"multiDailyMetricTimeSeries" => []}))

            String.ends_with?(conn.request_path, "/reviews") ->
              Plug.Conn.send_resp(conn, 200, Jason.encode!(%{"reviews" => []}))

            true ->
              Plug.Conn.send_resp(conn, 404, "")
          end
        end

        MetricFlowTest.PlugStore.put_provider_plug(:google_business, plug)

        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{
            "google_business_account_ids" => ["accounts/111", "accounts/222"],
            "included_locations" => [
              "accounts/111/locations/loc-a",
              "accounts/222/locations/loc-b"
            ]
          }
        )

        {:ok, Map.put(context, :requests_agent, agent)}
      end

      when_ "review syncing and performance-metric syncing run", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, context}
      end

      then_ "both cover locations from all of the customer's connected accounts, not just one", context do
        requests = Agent.get(context.requests_agent, & &1)

        assert Enum.any?(requests, &String.contains?(&1, "loc-a")),
               "Expected a request for the first account's location, got: #{inspect(MapSet.to_list(requests))}"

        assert Enum.any?(requests, &String.contains?(&1, "loc-b")),
               "Expected a request for the second account's location, got: #{inspect(MapSet.to_list(requests))}"

        {:ok, context}
      end
    end
  end
end
