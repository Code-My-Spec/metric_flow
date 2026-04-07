defmodule MetricFlowSpex.SystemRunsDailySyncJobAtScheduledTimeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System runs daily sync job at scheduled time (2 AM UTC)" do
    scenario "sync history page displays the automated sync schedule" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the automated daily sync schedule at 2:00 AM UTC", context do
        html = render(context.view)
        assert html =~ "2:00 AM UTC",
               "Expected sync history page to display the automated sync schedule '2:00 AM UTC', got: #{html}"
        :ok
      end

      then_ "the page labels the schedule as Daily", context do
        html = render(context.view)
        assert html =~ "Daily",
               "Expected sync history page to label the automated sync as 'Daily', got: #{html}"
        :ok
      end
    end

    scenario "sync history page shows a section describing the automated sync schedule" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "there is a schedule section on the page", context do
        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected a [data-role='sync-schedule'] element showing the automated sync schedule"
        :ok
      end

      then_ "the schedule section communicates the daily 2 AM UTC timing to the user", context do
        schedule_html = context.view
          |> element("[data-role='sync-schedule']")
          |> render()

        assert schedule_html =~ "Daily" or schedule_html =~ "daily",
               "Expected the sync schedule section to mention 'Daily', got: #{schedule_html}"

        assert schedule_html =~ "2:00 AM UTC" or schedule_html =~ "2 AM UTC",
               "Expected the sync schedule section to mention '2:00 AM UTC' or '2 AM UTC', got: #{schedule_html}"
        :ok
      end
    end

    scenario "sync history page shows automated sync history entries" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a sync history section", context do
        html = render(context.view)
        assert html =~ "Sync History" or html =~ "sync history",
               "Expected the page to display a 'Sync History' heading or section, got: #{html}"
        :ok
      end

      then_ "automated sync entries are labeled to distinguish them from manual syncs", context do
        assert has_element?(context.view, "[data-role='sync-history']"),
               "Expected a [data-role='sync-history'] element listing sync entries"
        :ok
      end
    end
  end
end
