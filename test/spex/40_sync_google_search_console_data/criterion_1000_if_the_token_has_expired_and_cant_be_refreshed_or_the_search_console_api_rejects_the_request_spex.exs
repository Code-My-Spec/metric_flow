defmodule MetricFlowSpex.ExpiredTokenOrApiRejectionFailsTheSyncClearlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If the token has expired and can't be refreshed, or the Search Console API rejects the request, the sync for that integration fails clearly with the error surfaced",
       fail_on_error_logs: false, criterion: 1000 do
    scenario "a property's token has expired and the refresh attempt fails" do
      given_ :user_logged_in_as_owner

      given_ "a property's token has expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_search_console,
          provider_metadata: %{"site_url" => "https://example.com/"},
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the sync tries to proceed", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync fails clearly and the error is surfaced rather than retried silently", context do
        assert has_element?(
                 context.view,
                 "[data-role='sync-history-entry'][data-status='failed'] [data-role='sync-provider']",
                 "Google Search Console"
               )

        assert has_element?(context.view, "[data-role='sync-error']")

        {:ok, context}
      end
    end
  end
end
