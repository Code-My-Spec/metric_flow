defmodule MetricFlowSpex.ExpiringOauthTokenIsRefreshedAutomaticallyDuringSyncSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Expiring OAuth token is refreshed automatically during sync", criterion: 615 do
    scenario "a sync completes without interruption despite a near-expiration token" do
      given_ :user_logged_in_as_owner

      given_ "an integration's OAuth token is nearing expiration", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), 30, :second)
        )

        {:ok, context}
      end

      when_ "the sync runs for that integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the token is refreshed automatically and the sync completes without interruption", context do
        refute has_element?(context.view, "[data-role='sync-error']", "reconnect")
        {:ok, context}
      end
    end
  end
end
