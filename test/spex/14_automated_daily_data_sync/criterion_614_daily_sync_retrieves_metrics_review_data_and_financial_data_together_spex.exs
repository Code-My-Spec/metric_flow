defmodule MetricFlowSpex.DailySyncRetrievesMetricsReviewAndFinancialDataTogetherSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Daily sync retrieves metrics, review data, and financial data together", fail_on_error_logs: false, criterion: 614 do
    scenario "a single daily sync run covers marketing, review, and financial integrations together" do
      given_ :user_logged_in_as_owner

      given_ "an account with marketing, review, and financial integrations", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business_reviews)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :quickbooks)
        {:ok, context}
      end

      when_ "the daily sync runs for a given day", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "metrics, review data, and financial data are all retrieved for that day", context do
        html = render(context.view)
        assert html =~ "Google Ads"
        assert html =~ "Google Business Reviews"
        assert html =~ "QuickBooks"
        {:ok, context}
      end
    end
  end
end
