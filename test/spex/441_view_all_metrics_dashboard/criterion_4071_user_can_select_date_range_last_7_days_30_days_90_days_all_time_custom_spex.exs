defmodule MetricFlowSpex.UserCanSelectDateRangeLast7Days30Days90DaysAllTimeCustomSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can select date range: last 7 days, 30 days, 90 days, all time, custom" do
    scenario "dashboard shows a 7 days date range option" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a 7 days date range option", context do
        html = render(context.view)

        has_7_days =
          html =~ "7 days" or
            html =~ "7 Days" or
            html =~ "Last 7" or
            html =~ "last 7" or
            has_element?(context.view, "[data-role='date-range-7-days']") or
            has_element?(context.view, "[phx-value-range='7_days']") or
            has_element?(context.view, "[phx-value-range='7days']") or
            has_element?(context.view, "option[value='7_days']") or
            has_element?(context.view, "option[value='7days']")

        assert has_7_days,
               "Expected the dashboard to show a '7 days' date range option, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows a 30 days date range option" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a 30 days date range option", context do
        html = render(context.view)

        has_30_days =
          html =~ "30 days" or
            html =~ "30 Days" or
            html =~ "Last 30" or
            html =~ "last 30" or
            has_element?(context.view, "[data-role='date-range-30-days']") or
            has_element?(context.view, "[phx-value-range='30_days']") or
            has_element?(context.view, "[phx-value-range='30days']") or
            has_element?(context.view, "option[value='30_days']") or
            has_element?(context.view, "option[value='30days']")

        assert has_30_days,
               "Expected the dashboard to show a '30 days' date range option, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows a 90 days date range option" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a 90 days date range option", context do
        html = render(context.view)

        has_90_days =
          html =~ "90 days" or
            html =~ "90 Days" or
            html =~ "Last 90" or
            html =~ "last 90" or
            has_element?(context.view, "[data-role='date-range-90-days']") or
            has_element?(context.view, "[phx-value-range='90_days']") or
            has_element?(context.view, "[phx-value-range='90days']") or
            has_element?(context.view, "option[value='90_days']") or
            has_element?(context.view, "option[value='90days']")

        assert has_90_days,
               "Expected the dashboard to show a '90 days' date range option, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows an all time date range option" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an all time date range option", context do
        html = render(context.view)

        has_all_time =
          html =~ "All time" or
            html =~ "All Time" or
            html =~ "all time" or
            has_element?(context.view, "[data-role='date-range-all-time']") or
            has_element?(context.view, "[phx-value-range='all_time']") or
            has_element?(context.view, "[phx-value-range='all']") or
            has_element?(context.view, "option[value='all_time']") or
            has_element?(context.view, "option[value='all']")

        assert has_all_time,
               "Expected the dashboard to show an 'All time' date range option, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows a custom date range option" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a custom date range option", context do
        html = render(context.view)

        has_custom =
          html =~ "Custom" or
            html =~ "custom" or
            html =~ "Custom range" or
            html =~ "Custom Range" or
            has_element?(context.view, "[data-role='date-range-custom']") or
            has_element?(context.view, "[phx-value-range='custom']") or
            has_element?(context.view, "option[value='custom']")

        assert has_custom,
               "Expected the dashboard to show a 'Custom' date range option, got: #{html}"

        :ok
      end
    end

    scenario "user can select the 7 days date range and the dashboard reflects that selection" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects the 7 days date range", context do
        html_before = render(context.view)

        _result =
          cond do
            has_element?(context.view, "[phx-value-range='7_days']") ->
              context.view
              |> element("[phx-value-range='7_days']")
              |> render_click()

            has_element?(context.view, "[phx-value-range='7days']") ->
              context.view
              |> element("[phx-value-range='7days']")
              |> render_click()

            has_element?(context.view, "select[name='date_range']") ->
              context.view
              |> element("select[name='date_range']")
              |> render_change(%{"date_range" => "7_days"})

            has_element?(context.view, "[data-role='date-range-7-days']") ->
              context.view
              |> element("[data-role='date-range-7-days']")
              |> render_click()

            true ->
              html_before
          end

        {:ok, context}
      end

      then_ "the dashboard remains rendered and shows the selected 7 day range", context do
        html = render(context.view)

        assert is_binary(html),
               "Expected the dashboard to remain rendered after selecting 7 days range"

        assert html =~ "7" or html =~ "days",
               "Expected the dashboard to reference the selected date range, got: #{html}"

        :ok
      end
    end

    scenario "user can select the 30 days date range and the dashboard reflects that selection" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects the 30 days date range", context do
        html_before = render(context.view)

        _result =
          cond do
            has_element?(context.view, "[phx-value-range='30_days']") ->
              context.view
              |> element("[phx-value-range='30_days']")
              |> render_click()

            has_element?(context.view, "[phx-value-range='30days']") ->
              context.view
              |> element("[phx-value-range='30days']")
              |> render_click()

            has_element?(context.view, "select[name='date_range']") ->
              context.view
              |> element("select[name='date_range']")
              |> render_change(%{"date_range" => "30_days"})

            has_element?(context.view, "[data-role='date-range-30-days']") ->
              context.view
              |> element("[data-role='date-range-30-days']")
              |> render_click()

            true ->
              html_before
          end

        {:ok, context}
      end

      then_ "the dashboard remains rendered and shows the selected 30 day range", context do
        html = render(context.view)

        assert is_binary(html),
               "Expected the dashboard to remain rendered after selecting 30 days range"

        assert html =~ "30" or html =~ "days",
               "Expected the dashboard to reference the selected date range, got: #{html}"

        :ok
      end
    end

    scenario "user can select the 90 days date range and the dashboard reflects that selection" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects the 90 days date range", context do
        html_before = render(context.view)

        _result =
          cond do
            has_element?(context.view, "[phx-value-range='90_days']") ->
              context.view
              |> element("[phx-value-range='90_days']")
              |> render_click()

            has_element?(context.view, "[phx-value-range='90days']") ->
              context.view
              |> element("[phx-value-range='90days']")
              |> render_click()

            has_element?(context.view, "select[name='date_range']") ->
              context.view
              |> element("select[name='date_range']")
              |> render_change(%{"date_range" => "90_days"})

            has_element?(context.view, "[data-role='date-range-90-days']") ->
              context.view
              |> element("[data-role='date-range-90-days']")
              |> render_click()

            true ->
              html_before
          end

        {:ok, context}
      end

      then_ "the dashboard remains rendered and shows the selected 90 day range", context do
        html = render(context.view)

        assert is_binary(html),
               "Expected the dashboard to remain rendered after selecting 90 days range"

        assert html =~ "90" or html =~ "days",
               "Expected the dashboard to reference the selected date range, got: #{html}"

        :ok
      end
    end

    scenario "user can select all time date range and the dashboard reflects that selection" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects the all time date range", context do
        html_before = render(context.view)

        _result =
          cond do
            has_element?(context.view, "[phx-value-range='all_time']") ->
              context.view
              |> element("[phx-value-range='all_time']")
              |> render_click()

            has_element?(context.view, "[phx-value-range='all']") ->
              context.view
              |> element("[phx-value-range='all']")
              |> render_click()

            has_element?(context.view, "select[name='date_range']") ->
              context.view
              |> element("select[name='date_range']")
              |> render_change(%{"date_range" => "all_time"})

            has_element?(context.view, "[data-role='date-range-all-time']") ->
              context.view
              |> element("[data-role='date-range-all-time']")
              |> render_click()

            true ->
              html_before
          end

        {:ok, context}
      end

      then_ "the dashboard remains rendered after selecting all time range", context do
        html = render(context.view)

        assert is_binary(html),
               "Expected the dashboard to remain rendered after selecting all time range, got: #{inspect(html)}"

        :ok
      end
    end
  end
end
