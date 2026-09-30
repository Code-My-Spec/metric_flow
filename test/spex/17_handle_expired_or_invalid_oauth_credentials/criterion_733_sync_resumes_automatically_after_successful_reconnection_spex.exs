defmodule MetricFlowSpex.SyncResumesAutomaticallyAfterSuccessfulReconnectionSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync resumes automatically after successful reconnection", criterion: 733 do
    scenario "a successfully reconnected integration is no longer flagged and needs no separate resume action" do
      given_(:user_logged_in_as_owner)

      given_ "the user successfully completes the Reconnect OAuth flow", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        MetricFlowSpex.Fixtures.reconnect_integration_for(context.owner_email, :google_ads)

        {:ok, context}
      end

      when_ "the reconnection succeeds", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "sync resumes automatically without a separate manual trigger", context do
        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'][data-status='connected']"
               )

        {:ok, context}
      end
    end
  end
end
