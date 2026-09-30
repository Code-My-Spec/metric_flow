defmodule MetricFlowSpex.CustomerWithoutAConfiguredSiteUrlIsSkippedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Customer without a configured site URL is skipped", criterion: 648 do
    scenario "a customer has no site URL configured" do
      given_ :user_logged_in_as_owner

      given_ "a customer has no site URL configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console)
        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "that customer is skipped rather than attempted or errored", context do
        refute has_element?(
                 context.view,
                 "[data-role='sync-history-entry'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        {:ok, context}
      end
    end
  end
end
