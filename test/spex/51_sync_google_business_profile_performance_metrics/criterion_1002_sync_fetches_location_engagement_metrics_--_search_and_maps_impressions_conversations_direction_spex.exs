defmodule MetricFlowSpex.Story51.Criterion1002Spex do
  @moduledoc """
  Story 51 — Sync Google Business Profile Performance Metrics.
  Criterion 1002 — fetch every specified engagement metric for a configured location.
  """

  use MetricFlowSpex.Case

  import MetricFlowSpex.SharedGivens

  @daily_metrics ~w(
    BUSINESS_IMPRESSIONS_DESKTOP_MAPS BUSINESS_IMPRESSIONS_DESKTOP_SEARCH
    BUSINESS_IMPRESSIONS_MOBILE_MAPS BUSINESS_IMPRESSIONS_MOBILE_SEARCH
    BUSINESS_CONVERSATIONS BUSINESS_DIRECTION_REQUESTS CALL_CLICKS
    WEBSITE_CLICKS BUSINESS_BOOKINGS BUSINESS_FOOD_ORDERS BUSINESS_FOOD_MENU_CLICKS
  )

  spex "Sync fetches each Google Business Profile engagement metric for a configured location",
    criterion: 1002 do
    scenario "the Performance API returns all engagement metrics for Jordan's location" do
      given_(:user_logged_in_as_owner)

      given_ "Jordan has a configured Google Business Profile location", context do
        # shortcut: OAuth is outside this sync criterion; use the existing connected-integration fixture until an OAuth-backed shared given exists.
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business,
          provider_metadata: %{
            "included_locations" => ["accounts/123/locations/456"]
          }
        )

        {:ok, context}
      end

      given_ "the Performance API has a daily value for every requested engagement metric",
             context do
        date = Date.add(Date.utc_today(), -1)

        series =
          Enum.with_index(@daily_metrics, 1)
          |> Enum.map(fn {metric, value} ->
            %{
              "dailyMetric" => metric,
              "timeSeries" => %{
                "datedValues" => [
                  %{
                    "date" => %{"year" => date.year, "month" => date.month, "day" => date.day},
                    "value" => Integer.to_string(value)
                  }
                ]
              }
            }
          end)

        body =
          Jason.encode!(%{"multiDailyMetricTimeSeries" => [%{"dailyMetricTimeSeries" => series}]})

        MetricFlowTest.SyncStub.stub_success(:google_business, body)
        {:ok, context}
      end

      when_ "Jordan triggers the daily sync", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, context}
      end

      then_ "all search and maps impressions, conversations, directions, calls, website clicks, bookings, food orders, and menu clicks are available",
            context do
        {:ok, dashboard, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        Enum.each(@daily_metrics, fn metric ->
          name = metric |> String.downcase() |> String.replace("business_", "")
          assert has_element?(dashboard, "[data-role='metric-chart'][data-metric='#{name}']")
        end)

        {:ok, context}
      end
    end
  end
end
