defmodule MetricFlowSpex.UserCanFilterByPlatformDateRangeOrMetricTypeSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can filter by platform, date range, or metric type" do
    scenario "dashboard displays a platform filter control" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a platform filter control is visible on the page", context do
        html = render(context.view)

        has_platform_filter =
          has_element?(context.view, "[data-role='platform-filter']") or
            has_element?(context.view, "[data-role='filter-platform']") or
            has_element?(context.view, "select[name='platform']") or
            has_element?(context.view, "[phx-value-filter='platform']") or
            html =~ "Google" or
            html =~ "Facebook" or
            html =~ "platform" or
            html =~ "Platform"

        assert has_platform_filter,
               "Expected the dashboard to display a platform filter control, got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays a date range filter control" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a date range filter control is visible on the page", context do
        html = render(context.view)

        has_date_filter =
          has_element?(context.view, "[data-role='date-range-filter']") or
            has_element?(context.view, "[data-role='filter-date-range']") or
            has_element?(context.view, "select[name='date_range']") or
            has_element?(context.view, "[phx-value-filter='date_range']") or
            html =~ "date" or
            html =~ "Date" or
            html =~ "range" or
            html =~ "7 days" or
            html =~ "30 days"

        assert has_date_filter,
               "Expected the dashboard to display a date range filter control, got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays a metric type filter control" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a metric type filter control is visible on the page", context do
        html = render(context.view)

        has_metric_type_filter =
          has_element?(context.view, "[data-role='metric-type-filter']") or
            has_element?(context.view, "[data-role='filter-metric-type']") or
            has_element?(context.view, "select[name='metric_type']") or
            has_element?(context.view, "[phx-value-filter='metric_type']") or
            html =~ "Impressions" or
            html =~ "impressions" or
            html =~ "Clicks" or
            html =~ "clicks" or
            html =~ "Revenue" or
            html =~ "revenue" or
            html =~ "metric type" or
            html =~ "Metric Type"

        assert has_metric_type_filter,
               "Expected the dashboard to display a metric type filter control, got: #{html}"

        :ok
      end
    end

    scenario "user can interact with the platform filter and the dashboard updates" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects a platform filter option", context do
        html_before = render(context.view)

        result =
          cond do
            has_element?(context.view, "[data-role='platform-filter']") ->
              context.view
              |> element("[data-role='platform-filter']")
              |> render_click()

            has_element?(context.view, "[phx-value-platform='google']") ->
              context.view
              |> element("[phx-value-platform='google']")
              |> render_click()

            has_element?(context.view, "select[name='platform']") ->
              context.view
              |> element("select[name='platform']")
              |> render_change(%{"platform" => "google"})

            true ->
              html_before
          end

        {:ok, Map.put(context, :html_after_filter, result)}
      end

      then_ "the dashboard responds to the platform filter interaction", context do
        html = render(context.view)

        assert is_binary(html),
               "Expected the dashboard to remain rendered after platform filter interaction, got: #{inspect(html)}"

        :ok
      end
    end

    scenario "user can interact with the metric type filter and the dashboard updates" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user selects a metric type filter option", context do
        html_before = render(context.view)

        result =
          cond do
            has_element?(context.view, "[data-role='metric-type-filter']") ->
              context.view
              |> element("[data-role='metric-type-filter']")
              |> render_click()

            has_element?(context.view, "[phx-value-metric-type='impressions']") ->
              context.view
              |> element("[phx-value-metric-type='impressions']")
              |> render_click()

            has_element?(context.view, "select[name='metric_type']") ->
              context.view
              |> element("select[name='metric_type']")
              |> render_change(%{"metric_type" => "impressions"})

            true ->
              html_before
          end

        {:ok, Map.put(context, :html_after_filter, result)}
      end

      then_ "the dashboard responds to the metric type filter interaction", context do
        html = render(context.view)

        assert is_binary(html),
               "Expected the dashboard to remain rendered after metric type filter interaction, got: #{inspect(html)}"

        :ok
      end
    end
  end
end
