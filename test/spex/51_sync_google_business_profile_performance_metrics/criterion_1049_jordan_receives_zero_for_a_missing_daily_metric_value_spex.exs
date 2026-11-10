defmodule MetricFlowSpex.Story51.Criterion1049Spex do
  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  spex "Jordan receives zero for a missing daily Google Business Profile metric value",
    criterion: 1049 do
    scenario "Google omits the value for a day with call clicks" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan connected a Google Business Profile location", context do
        # shortcut: OAuth is outside this metric-value criterion; replace with an OAuth-backed shared given when available.
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{"included_locations" => ["accounts/123/locations/456"]}
        )

        {:ok, context}
      end

      given_ "Google returns a daily call-click entry with a null value", context do
        date = Date.add(Date.utc_today(), -1)

        body =
          Jason.encode!(%{
            "multiDailyMetricTimeSeries" => [
              %{
                "dailyMetricTimeSeries" => [
                  %{
                    "dailyMetric" => "CALL_CLICKS",
                    "timeSeries" => %{
                      "datedValues" => [
                        %{
                          "date" => %{
                            "year" => date.year,
                            "month" => date.month,
                            "day" => date.day
                          },
                          "value" => nil
                        }
                      ]
                    }
                  }
                ]
              }
            ]
          })

        MetricFlowTest.SyncStub.stub_success(:google_business, body)
        {:ok, Map.put(context, :metric_date, Date.to_iso8601(date))}
      end

      when_ "Jordan syncs and opens the Google Business Profile dashboard", context do
        {:ok, history, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        history |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)

        {:ok, dashboard, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.put(context, :dashboard, dashboard)}
      end

      then_ "Jordan sees zero for that location and day", context do
        assert has_element?(
                 context.dashboard,
                 "[data-role='daily-location-metric'][data-location-id='accounts/123/locations/456'][data-metric='call_clicks'][data-date='#{context.metric_date}']",
                 "0"
               )

        {:ok, context}
      end
    end
  end
end
