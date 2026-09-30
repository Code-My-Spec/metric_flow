defmodule MetricFlowSpex.ExpiringTokenIsRefreshedBeforeTheApiCallSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Expiring token is refreshed before the API call", criterion: 655 do
    scenario "a property's token is nearing expiry" do
      given_ :user_logged_in_as_owner

      given_ "a property's token is nearing expiry", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"},
          expires_at: DateTime.add(DateTime.utc_now(), 60, :second)
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the token is refreshed successfully before the API call proceeds", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='success'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        {:ok, context}
      end
    end
  end
end
