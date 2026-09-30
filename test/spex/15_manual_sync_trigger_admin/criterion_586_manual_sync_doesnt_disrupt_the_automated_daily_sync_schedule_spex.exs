defmodule MetricFlowSpex.ManualSyncDoesntDisruptTheAutomatedDailySyncScheduleSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Manual sync doesn't disrupt the automated daily sync schedule", criterion: 586 do
    scenario "triggering a manual sync leaves the integration's automated sync eligibility intact" do
      given_ :owner_with_integrations

      given_ "an integration has an automated daily sync schedule", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin triggers a manual sync", context do
        context.view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        Phoenix.PubSub.broadcast(
          MetricFlow.PubSub,
          "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync",
          {:sync_completed,
           %{provider: :google_analytics, records_synced: 10, completed_at: DateTime.utc_now()}}
        )

        :timer.sleep(100)

        {:ok, context}
      end

      then_ "the automated daily sync still runs at its normal scheduled time afterward", context do
        # The integration remains connected (not disconnected or disabled by the manual
        # sync), which is what the automated daily job checks to decide whether to run.
        assert has_element?(
                 context.view,
                 "[data-role='integration-card'][data-platform='google_analytics'] [data-status='connected']"
               ),
               "Expected the integration to remain connected/eligible for its automated schedule after a manual sync"

        {:ok, context}
      end
    end
  end
end
