defmodule MetricFlowSpex.NewlyAddedLocationBackfills548DaysOnFirstSyncSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Newly added location backfills 548 days on first sync", criterion: 942 do
    scenario "a newly added location's first sync requests performance data starting 548 days back" do
      given_ :user_logged_in_as_owner

      given_ "a user adds a new location to their sync configuration", context do
        {:ok, agent} = Agent.start_link(fn -> [] end)

        plug = fn conn ->
          conn = Plug.Conn.put_resp_content_type(conn, "application/json")

          cond do
            String.contains?(conn.request_path, ":fetchMultiDailyMetricsTimeSeries") ->
              %{query_params: query} = Plug.Conn.fetch_query_params(conn)
              Agent.update(agent, fn reqs -> [query | reqs] end)
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
            "google_business_account_ids" => ["accounts/111"],
            "included_locations" => ["accounts/111/locations/new-loc"]
          }
        )

        {:ok, Map.put(context, :requests_agent, agent)}
      end

      when_ "it syncs for the first time", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, context}
      end

      then_ "it backfills 548 days of history, consistent with existing GBP backfill behavior", context do
        requests = Agent.get(context.requests_agent, & &1)
        assert requests != [], "Expected at least one performance metrics request to have been made"

        expected_start = Date.add(Date.utc_today(), -548)

        assert Enum.any?(requests, fn query ->
                 query["dailyRange.startDate.year"] == Integer.to_string(expected_start.year) and
                   query["dailyRange.startDate.month"] == Integer.to_string(expected_start.month) and
                   query["dailyRange.startDate.day"] == Integer.to_string(expected_start.day)
               end),
               "Expected a request with startDate #{inspect(expected_start)}, got: #{inspect(requests)}"

        {:ok, context}
      end
    end
  end
end
