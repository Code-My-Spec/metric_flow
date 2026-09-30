defmodule MetricFlowSpex.DefaultDateRangeExcludesTodaySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Default date range excludes today", criterion: 751 do
    scenario "a client opens the dashboard with the default date range before today's data has fully synced" do
      given_(:user_logged_in_as_owner)

      given_ "a client has connected data, including a metric recorded today", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 999.0,
          recorded_at: DateTime.new!(Date.utc_today(), ~T[00:00:00], "Etc/UTC")
        })

        {:ok, context}
      end

      when_ "today's data has not yet fully synced and they open the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the range is counted back from yesterday rather than including today", context do
        html = render(context.view)

        assert html =~ "today excluded",
               "Expected the dashboard to state that today is excluded from the default range, got: #{html}"

        {:ok, context}
      end
    end
  end
end
