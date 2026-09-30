defmodule MetricFlowSpex.DailySyncPullsNewDataFromEveryActiveIntegrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Daily sync pulls new data from every active integration", fail_on_error_logs: false, criterion: 610 do
    scenario "an account with multiple active integrations gets new data for all of them" do
      given_ :user_logged_in_as_owner

      given_ "the account has multiple active integrations", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)
        {:ok, context}
      end

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "new data is pulled for every active integration", context do
        html = render(context.view)
        assert html =~ "Google Ads"
        assert html =~ "Facebook Ads"
        {:ok, context}
      end
    end
  end
end
