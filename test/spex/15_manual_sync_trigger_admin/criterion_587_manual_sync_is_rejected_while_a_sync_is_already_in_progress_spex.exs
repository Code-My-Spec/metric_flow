defmodule MetricFlowSpex.ManualSyncIsRejectedWhileASyncIsAlreadyInProgressSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Manual sync is rejected while a sync is already in progress", criterion: 587 do
    scenario "attempting a second manual sync while one is already running is rejected" do
      given_ :owner_with_integrations

      given_ "a sync (manual or automated) is already running for an integration", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")

        view
        |> element("[data-platform='google_analytics'] button[phx-click='sync']", "Sync Now")
        |> render_click()

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin attempts to trigger another manual sync for that same integration", context do
        # Dispatch the raw event directly: the disabled button already prevents this
        # through the UI, so the request must actually be rejected server-side too.
        render_click(context.view, "sync", %{
          "platform" => "google_analytics",
          "provider" => "google_analytics"
        })

        {:ok, Map.put(context, :html, render(context.view))}
      end

      then_ "the request is rejected and the admin is told a sync is already in progress", context do
        assert context.html =~ "already in progress" or context.html =~ "already syncing",
               "Expected the admin to be told a sync is already in progress, got: #{context.html}"

        {:ok, context}
      end
    end
  end
end
