defmodule MetricFlowSpex.TokenExpiryCheckedBeforeApiCallSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Token expiry is checked before each API call, with refresh attempted on an expired token before proceeding",
       criterion: 358 do
    scenario "a sync for an integration with an expired token still proceeds rather than being silently dropped" do
      given_ :user_logged_in_as_owner

      given_ "a Search Console integration exists whose token has already expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"},
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the sync runs", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync attempts the call after a refresh, rather than aborting outright on the expired token",
            context do
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
