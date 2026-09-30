defmodule MetricFlowSpex.BackfillIsLimitedToWhatThePlatformsApiAllowsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Backfill is limited to what the platform's API allows", fail_on_error_logs: false, criterion: 612 do
    scenario "a platform with a limited historical window backfills only what it allows, and says so" do
      given_ :user_logged_in_as_owner

      given_ "a platform's API only exposes a limited historical window", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          provider_metadata: %{"customer_id" => "1234567890"}
        )
        {:ok, context}
      end

      when_ "the first sync backfills that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "only data within the platform's allowed window is backfilled, and the limitation is noted", context do
        assert has_element?(context.view, "[data-sync-type='initial']")
        assert has_element?(context.view, "[data-role='backfill-limit-notice']")
        {:ok, context}
      end
    end
  end
end
