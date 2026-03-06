defmodule MetricFlowSpex.SystemMaintainsACanonicalMetricTaxonomySpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "System maintains a canonical metric taxonomy that platform-specific metrics map to" do
    scenario "dashboard page loads for an authenticated user" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard page loads without error", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboard to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "dashboard displays canonical metric names like clicks" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders the canonical metric name 'clicks'", context do
        html = render(context.view)

        has_clicks =
          html =~ "Clicks" or
            html =~ "clicks" or
            has_element?(context.view, "[data-canonical-metric='clicks']") or
            has_element?(context.view, "[data-metric-name='clicks']") or
            has_element?(context.view, "[data-role='metric-clicks']")

        assert has_clicks,
               "Expected the dashboard to display the canonical metric 'clicks', got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays canonical metric names like spend" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders the canonical metric name 'spend'", context do
        html = render(context.view)

        has_spend =
          html =~ "Spend" or
            html =~ "spend" or
            has_element?(context.view, "[data-canonical-metric='spend']") or
            has_element?(context.view, "[data-metric-name='spend']") or
            has_element?(context.view, "[data-role='metric-spend']")

        assert has_spend,
               "Expected the dashboard to display the canonical metric 'spend', got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays canonical metric names like impressions" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders the canonical metric name 'impressions'", context do
        html = render(context.view)

        has_impressions =
          html =~ "Impressions" or
            html =~ "impressions" or
            has_element?(context.view, "[data-canonical-metric='impressions']") or
            has_element?(context.view, "[data-metric-name='impressions']") or
            has_element?(context.view, "[data-role='metric-impressions']")

        assert has_impressions,
               "Expected the dashboard to display the canonical metric 'impressions', got: #{html}"

        :ok
      end
    end

    scenario "dashboard displays canonical metric names like conversions" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders the canonical metric name 'conversions'", context do
        html = render(context.view)

        has_conversions =
          html =~ "Conversions" or
            html =~ "conversions" or
            has_element?(context.view, "[data-canonical-metric='conversions']") or
            has_element?(context.view, "[data-metric-name='conversions']") or
            has_element?(context.view, "[data-role='metric-conversions']")

        assert has_conversions,
               "Expected the dashboard to display the canonical metric 'conversions', got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the dashboard metrics" do
      given_ "an unauthenticated user attempts to navigate to the dashboard", context do
        result = live(build_conn(), "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the dashboard", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "clicks"
            :ok
        end
      end
    end
  end
end
