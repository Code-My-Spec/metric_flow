defmodule MetricFlowSpex.Story51.Criterion1050Spex do
  use MetricFlowSpex.Case
  import MetricFlowSpex.SharedGivens

  spex "Jordan's repeated sync updates a daily value without duplication", criterion: 1050 do
    scenario "a corrected call-click count replaces the earlier daily count" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan connected a Google Business Profile location", context do
        # shortcut: OAuth is outside this daily-value criterion; replace with an OAuth-backed shared given when available.
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["accounts/123/locations/456"]}
        )

        {:ok, context}
      end

      given_ "Google reports seven call clicks for yesterday", context do
        date = Date.add(Date.utc_today(), -1)
        MetricFlowTest.SyncStub.stub_success(:google_business, performance_body(7, date))
        {:ok, Map.put(context, :metric_date, Date.to_iso8601(date))}
      end

      when_ "Jordan syncs, Google corrects the count to eleven, and Jordan syncs again",
            context do
        {:ok, history, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        date = Date.from_iso8601!(context.metric_date)
        MetricFlowTest.SyncStub.stub_success(:google_business, performance_body(11, date))
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        {:ok, dashboard, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.put(context, :dashboard, dashboard)}
      end

      then_ "Jordan sees only the corrected daily value for that location", context do
        selector =
          "[data-role='daily-location-metric'][data-location-id='accounts/123/locations/456'][data-metric='call_clicks'][data-date='#{context.metric_date}']"

        assert has_element?(context.dashboard, selector, "11")
        refute has_element?(context.dashboard, selector, "7")
        {:ok, context}
      end
    end
  end

  defp performance_body(value, date) do
    Jason.encode!(%{
      "multiDailyMetricTimeSeries" => [
        %{
          "dailyMetricTimeSeries" => [
            %{
              "dailyMetric" => "CALL_CLICKS",
              "timeSeries" => %{
                "datedValues" => [
                  %{
                    "date" => %{"year" => date.year, "month" => date.month, "day" => date.day},
                    "value" => Integer.to_string(value)
                  }
                ]
              }
            }
          ]
        }
      ]
    })
  end
end
