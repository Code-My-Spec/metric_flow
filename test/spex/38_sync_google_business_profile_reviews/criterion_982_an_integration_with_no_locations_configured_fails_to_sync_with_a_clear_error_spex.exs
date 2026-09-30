defmodule MetricFlowSpex.Criterion982NoLocationsConfiguredFailsWithClearErrorSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "An integration with no locations configured fails to sync with a clear error",
       fail_on_error_logs: false,
       criterion: 982 do
    scenario "a Google Business Profile integration has no location configured" do
      given_ :user_logged_in_as_owner

      given_ "a Google Business Profile integration has no location configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_business_reviews)
        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync fails with a clear error", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Google Business Reviews"
               )

        assert has_element?(context.view, "[data-role='sync-error']")
        {:ok, context}
      end
    end
  end
end
