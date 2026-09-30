defmodule MetricFlowSpex.TokenRefreshFailureCausesThatIntegrationsSyncToFailSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Token refresh failure causes that integration's sync to fail", fail_on_error_logs: false, criterion: 616 do
    scenario "an integration whose refresh token is no longer honored fails its sync for the cycle" do
      given_ :user_logged_in_as_owner

      given_ "an integration's OAuth refresh token has been revoked", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the sync attempts to refresh the token", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        view |> element("[data-role='trigger-daily-sync']") |> render_click()
        Oban.drain_queue(queue: :sync)
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the refresh fails and that integration's sync for the cycle fails", context do
        assert has_element?(context.view, "[data-role='sync-history-entry'][data-status='failed']")
        {:ok, context}
      end
    end
  end
end
