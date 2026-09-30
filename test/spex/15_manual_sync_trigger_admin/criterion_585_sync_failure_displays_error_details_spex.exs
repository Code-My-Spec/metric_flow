defmodule MetricFlowSpex.SyncFailureDisplaysErrorDetailsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Sync failure displays error details", criterion: 585 do
    scenario "when a manual sync fails, the admin sees the error details explaining why" do
      given_ :owner_with_integrations

      given_ "a manual sync fails (e.g. the platform rejects the request)", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")

        Phoenix.PubSub.broadcast(
          MetricFlow.PubSub,
          "user:#{MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email).id}:sync",
          {:sync_failed, %{provider: :google_analytics, reason: "API rate limit exceeded"}}
        )

        :timer.sleep(100)

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin views the integration", context do
        {:ok, Map.put(context, :html, render(context.view))}
      end

      then_ "they see the error details explaining why the sync failed", context do
        assert context.html =~ "API rate limit exceeded",
               "Expected the page to show the specific failure reason, got: #{context.html}"

        {:ok, context}
      end
    end
  end
end
