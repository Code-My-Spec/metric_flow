defmodule MetricFlowSpex.ReportIncludesMetricsFromMultipleConnectedPlatformsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Report includes metrics from multiple connected platforms", criterion: 930 do
    scenario "the metric picker offers metrics from both marketing and financial platforms" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "a user has both marketing and financial platforms connected", context do
        dt = DateTime.new!(Date.add(Date.utc_today(), -1), ~T[00:00:00], "Etc/UTC")

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          metric_name: "Clicks",
          provider: :google_ads,
          value: 42.0,
          recorded_at: dt
        })

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          metric_name: "Revenue",
          provider: :quickbooks,
          value: 500.0,
          recorded_at: dt
        })

        {:ok, context}
      end

      when_ "they build a report", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards/new")

        view
        |> element("[data-role='add-visualization-btn']")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "they can include metrics from both marketing and financial platforms in the same report",
            context do
        html = render(context.view)
        assert html =~ "Clicks"
        assert html =~ "Revenue"
        {:ok, context}
      end
    end
  end
end
