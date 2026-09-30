defmodule MetricFlowSpex.DataIsFetchedPerSiteUrlConfiguredPerCustomerSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Data is fetched per site URL configured per customer; customers without a site URL are skipped",
       criterion: 351 do
    scenario "a customer with no configured site URL is not fetched as a failure" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists with no site URL configured", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{}
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the customer is skipped rather than attempted and marked failed", context do
        refute has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        {:ok, context}
      end
    end
  end
end
