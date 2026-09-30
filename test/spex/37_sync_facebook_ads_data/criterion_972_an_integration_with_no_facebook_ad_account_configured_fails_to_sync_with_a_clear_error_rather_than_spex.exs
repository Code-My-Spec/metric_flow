defmodule MetricFlowSpex.Criterion972NoAdAccountConfiguredFailsRatherThanSilentlySkippedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "An integration with no Facebook ad account configured fails to sync with a clear error rather than being silently skipped",
       criterion: 972 do
    scenario "a Facebook Ads integration has no ad account configured" do
      given_ :user_logged_in_as_owner

      given_ "a Facebook Ads integration has no ad account configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :facebook_ads)
        {:ok, context}
      end

      when_ "the daily sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync fails with a clear error rather than being silently skipped", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Facebook Ads"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
