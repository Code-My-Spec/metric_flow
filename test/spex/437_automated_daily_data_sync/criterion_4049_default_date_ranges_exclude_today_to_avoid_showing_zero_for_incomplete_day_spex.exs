defmodule MetricFlowSpex.DefaultDateRangesExcludeTodayToAvoidShowingZeroForIncompleteDaySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Default date ranges exclude today to avoid showing zero for incomplete day" do
    scenario "sync history page does not include today's date in the default date range end" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page renders a date range that ends at yesterday, not today", context do
        html = render(context.view)
        today = Date.utc_today() |> Date.to_string()

        refute html =~ "Through #{today}" ,
               "Expected the default date range end to be yesterday, not today (#{today})"

        refute html =~ "through #{today}",
               "Expected the default date range end to be yesterday, not today (#{today})"

        :ok
      end

      then_ "the page shows a date range end of yesterday", context do
        html = render(context.view)
        yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_string()

        assert html =~ yesterday,
               "Expected the sync history page to display yesterday (#{yesterday}) as the end of the default date range, got: #{html}"

        :ok
      end
    end

    scenario "the date range picker defaults to ending at yesterday rather than today" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a date range element is present on the page", context do
        assert has_element?(context.view, "[data-role='date-range']"),
               "Expected a [data-role='date-range'] element showing the current date range filter"

        :ok
      end

      then_ "the date range element shows yesterday as the end date", context do
        yesterday = Date.utc_today() |> Date.add(-1) |> Date.to_string()

        date_range_html = context.view
          |> element("[data-role='date-range']")
          |> render()

        assert date_range_html =~ yesterday,
               "Expected the [data-role='date-range'] element to display yesterday (#{yesterday}) as the end date, got: #{date_range_html}"

        :ok
      end

      then_ "today's date does not appear as the range end date", context do
        today = Date.utc_today() |> Date.to_string()

        date_range_html = context.view
          |> element("[data-role='date-range']")
          |> render()

        refute date_range_html =~ "to #{today}" or date_range_html =~ "through #{today}" or
                 date_range_html =~ "- #{today}",
               "Expected today (#{today}) to be excluded from the default date range end, got: #{date_range_html}"

        :ok
      end
    end

    scenario "sync history page communicates to the user that data through yesterday is shown" do
      given_ :owner_with_integrations

      given_ "the user navigates to the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays explanatory text indicating today is excluded from the range", context do
        html = render(context.view)

        has_yesterday_label =
          html =~ "yesterday" or
            html =~ "Yesterday" or
            html =~ "through yesterday" or
            html =~ "Through yesterday" or
            html =~ "excludes today" or
            html =~ "incomplete day"

        assert has_yesterday_label,
               "Expected the sync history page to communicate that the default range ends at yesterday " <>
                 "(e.g. 'through yesterday', 'excludes today', or 'incomplete day'), got: #{html}"

        :ok
      end
    end
  end
end
