defmodule MetricFlowSpex.AfterSuccessfulReconnectionSyncResumesAutomaticallySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "After successful reconnection, sync resumes automatically", criterion: 126 do
    scenario "a reconnected integration returns to connected status without further manual action" do
      given_(:user_logged_in_as_owner)

      given_ "an integration's credentials had expired", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads,
          expires_at: DateTime.add(DateTime.utc_now(), -3600, :second)
        )

        {:ok, context}
      end

      when_ "the user successfully reconnects the integration", context do
        MetricFlowSpex.Fixtures.reconnect_integration_for(context.owner_email, :google_ads)
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integration shows as connected again, so scheduled syncs are no longer skipped",
            context do
        refute has_element?(
                 context.view,
                 "[data-platform='google_ads'][data-status='error']"
               )

        assert has_element?(
                 context.view,
                 "[data-platform='google_ads'][data-status='connected']"
               )

        {:ok, context}
      end
    end
  end
end
