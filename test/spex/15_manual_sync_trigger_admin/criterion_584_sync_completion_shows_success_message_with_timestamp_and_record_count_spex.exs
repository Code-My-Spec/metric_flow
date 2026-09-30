defmodule MetricFlowSpex.SyncCompletionShowsSuccessMessageWithTimestampAndRecordCountSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync completion shows success message with timestamp and record count", criterion: 584 do
    scenario "after a manual sync completes, the admin sees the completion timestamp and record count" do
      given_ :owner_with_integrations

      given_ "a manual sync completes successfully", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")

        completed_at = DateTime.utc_now()

        Phoenix.PubSub.broadcast(
          MetricFlow.PubSub,
          "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync",
          {:sync_completed,
           %{provider: :google_analytics, records_synced: 42, completed_at: completed_at}}
        )

        :timer.sleep(100)

        {:ok, Map.merge(context, %{view: view, completed_at: completed_at})}
      end

      when_ "the admin views the integration", context do
        {:ok, Map.put(context, :html, render(context.view))}
      end

      then_ "they see a success message showing the completion timestamp and the number of records synced",
            context do
        assert context.html =~ "42",
               "Expected the success message to show the record count, got: #{context.html}"

        assert context.html =~
                 Calendar.strftime(context.completed_at, "%Y-%m-%d"),
               "Expected the success message to show the completion timestamp, got: #{context.html}"

        {:ok, context}
      end
    end
  end
end
