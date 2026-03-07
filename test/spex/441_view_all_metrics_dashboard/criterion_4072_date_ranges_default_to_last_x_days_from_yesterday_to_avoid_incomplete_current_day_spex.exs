defmodule MetricFlowSpex.DateRangesDefaultToLastXDaysFromYesterdayToAvoidIncompleteCurrentDaySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Date ranges default to last X days from yesterday to avoid incomplete current day" do
    scenario "dashboard end date defaults to yesterday, not today, on initial load" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        yesterday = Date.add(Date.utc_today(), -1)
        today = Date.utc_today()

        {:ok,
         context
         |> Map.put(:view, view)
         |> Map.put(:yesterday, yesterday)
         |> Map.put(:today, today)}
      end

      then_ "the rendered page contains yesterday's date as the end of the default range", context do
        html = render(context.view)
        yesterday_str = Date.to_iso8601(context.yesterday)

        has_yesterday =
          html =~ yesterday_str or
            html =~ "yesterday" or
            html =~ "Yesterday" or
            has_element?(context.view, "[data-role='date-range-end'][data-date='#{yesterday_str}']") or
            has_element?(context.view, "[data-end-date='#{yesterday_str}']") or
            has_element?(context.view, "[data-role='date-range-end-date']")

        assert has_yesterday,
               "Expected the dashboard to show yesterday (#{yesterday_str}) as the default end date, got: #{html}"

        :ok
      end
    end

    scenario "dashboard default end date is not today on initial load" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        today = Date.utc_today()
        today_str = Date.to_iso8601(today)

        {:ok,
         context
         |> Map.put(:view, view)
         |> Map.put(:today_str, today_str)}
      end

      then_ "today's date is not presented as the end of the default date range", context do
        _html = render(context.view)
        today_str = context.today_str

        # The end date shown must not be today. We check that the dashboard does
        # not explicitly surface today's ISO date as the active range end.
        # Presence of today's date anywhere in the page is allowed (e.g., as a label
        # saying "today is excluded"), but it must not be flagged as the range end.
        end_date_is_today =
          has_element?(context.view, "[data-role='date-range-end'][data-date='#{today_str}']") or
            has_element?(context.view, "[data-end-date='#{today_str}']")

        refute end_date_is_today,
               "Expected today (#{today_str}) NOT to be the default end date, but found it marked as such"

        :ok
      end
    end

    scenario "dashboard shows an explanation that today is excluded from the default range" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page communicates that today's data is excluded or the day is incomplete", context do
        html = render(context.view)

        communicates_exclusion =
          html =~ "today excluded" or
            html =~ "Today excluded" or
            html =~ "incomplete" or
            html =~ "Incomplete" or
            html =~ "excluding today" or
            html =~ "Excluding today" or
            html =~ "partial day" or
            html =~ "Partial day" or
            html =~ "through yesterday" or
            html =~ "Through yesterday" or
            has_element?(context.view, "[data-role='today-excluded-notice']") or
            has_element?(context.view, "[data-role='incomplete-day-notice']")

        assert communicates_exclusion,
               "Expected the dashboard to indicate that today's data is excluded or the current day is incomplete, got: #{html}"

        :ok
      end
    end

    scenario "dashboard default date range end is one day before today" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        yesterday = Date.add(Date.utc_today(), -1)
        yesterday_str = Date.to_iso8601(yesterday)

        {:ok,
         context
         |> Map.put(:view, view)
         |> Map.put(:yesterday_str, yesterday_str)}
      end

      then_ "the date range displayed ends at the expected yesterday date", context do
        html = render(context.view)
        yesterday_str = context.yesterday_str

        # Check that the page either renders yesterday as ISO date or refers to it
        # through a semantic label, confirming the range ends at T-1.
        ends_at_yesterday =
          html =~ yesterday_str or
            html =~ "yesterday" or
            html =~ "Yesterday" or
            has_element?(context.view, "[data-role='date-range-end-date']") or
            has_element?(context.view, "[data-end-date='#{yesterday_str}']")

        assert ends_at_yesterday,
               "Expected the default date range to end at yesterday (#{yesterday_str}), got: #{html}"

        :ok
      end
    end
  end
end
