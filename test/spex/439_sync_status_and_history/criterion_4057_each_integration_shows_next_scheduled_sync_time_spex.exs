defmodule MetricFlowSpex.EachIntegrationShowsNextScheduledSyncTimeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each integration shows next scheduled sync time" do
    scenario "sync history page shows the scheduled sync time so users know when to expect the next sync" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays the next scheduled sync time", context do
        html = render(context.view)

        has_next_sync_info =
          html =~ "Next sync" or
            html =~ "next sync" or
            html =~ "2:00 AM UTC" or
            html =~ "2 AM UTC"

        assert has_next_sync_info,
               "Expected the sync history page to show when the next sync will run " <>
                 "(e.g. 'Next sync', '2:00 AM UTC'), got: #{html}"

        :ok
      end
    end

    scenario "the sync schedule section communicates the next sync timing" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the sync schedule section is visible on the page", context do
        assert has_element?(context.view, "[data-role='sync-schedule']"),
               "Expected a [data-role='sync-schedule'] element showing the sync schedule"

        :ok
      end

      then_ "the sync schedule section shows when the next sync will run", context do
        schedule_html =
          context.view
          |> element("[data-role='sync-schedule']")
          |> render()

        has_next_sync_time =
          schedule_html =~ "2:00 AM UTC" or
            schedule_html =~ "2 AM UTC" or
            schedule_html =~ "Next sync" or
            schedule_html =~ "next sync"

        assert has_next_sync_time,
               "Expected the [data-role='sync-schedule'] section to show when the next sync will run " <>
                 "(e.g. '2:00 AM UTC' or 'Next sync'), got: #{schedule_html}"

        :ok
      end
    end

    scenario "users can see the daily schedule so they understand data freshness timing" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows the sync recurrence as daily", context do
        schedule_html =
          context.view
          |> element("[data-role='sync-schedule']")
          |> render()

        assert schedule_html =~ "Daily" or schedule_html =~ "daily",
               "Expected the sync schedule section to indicate the sync runs daily, got: #{schedule_html}"

        :ok
      end

      then_ "the page shows the exact time the daily sync runs", context do
        schedule_html =
          context.view
          |> element("[data-role='sync-schedule']")
          |> render()

        assert schedule_html =~ "2:00 AM UTC" or schedule_html =~ "2 AM UTC",
               "Expected the sync schedule section to display the scheduled sync time " <>
                 "(e.g. '2:00 AM UTC'), got: #{schedule_html}"

        :ok
      end
    end
  end
end
