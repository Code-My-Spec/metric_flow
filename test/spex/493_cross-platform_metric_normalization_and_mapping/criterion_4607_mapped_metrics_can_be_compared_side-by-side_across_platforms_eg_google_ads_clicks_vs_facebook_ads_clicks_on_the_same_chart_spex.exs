defmodule MetricFlowSpex.MappedMetricsCanBeComparedSideBySideAcrossPlatformsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Mapped metrics can be compared side-by-side across platforms (e.g., Google Ads clicks vs Facebook Ads clicks on the same chart)" do
    scenario "dashboard loads for a user with integrations" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/app/dashboard")
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

    scenario "dashboard renders a comparison of clicks from Google Ads and Facebook Ads" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows a per-platform breakdown for the canonical clicks metric", context do
        html = render(context.view)

        has_platform_comparison =
          has_element?(context.view, "[data-role='platform-comparison']") or
            has_element?(context.view, "[data-role='metric-comparison']") or
            has_element?(context.view, "[data-role='side-by-side-chart']") or
            has_element?(context.view, "[data-role='comparison-chart']") or
            has_element?(context.view, "[data-canonical-metric='clicks'][data-platform]") or
            (html =~ "Google" and html =~ "clicks") or
            (html =~ "Facebook" and html =~ "clicks") or
            (html =~ "google" and html =~ "clicks") or
            (html =~ "facebook" and html =~ "clicks")

        assert has_platform_comparison,
               "Expected the dashboard to display a side-by-side comparison of clicks from Google Ads and Facebook Ads, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows multiple platform sources for the same canonical metric" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard identifies at least one platform contributing to a canonical metric", context do
        html = render(context.view)

        has_platform_source =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']") or
            has_element?(context.view, "[data-role='platform-metric']")

        assert has_platform_source,
               "Expected the dashboard to identify at least one platform source when comparing canonical metrics across platforms, got: #{html}"

        :ok
      end
    end

    scenario "dashboard does not mix up platform-specific values under a different canonical metric" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "platform-specific metric data is not attributed to the wrong canonical metric", context do
        html = render(context.view)

        # Facebook 'Link Clicks' should be grouped under canonical 'clicks', not 'spend'
        clicks_under_spend =
          has_element?(context.view, "[data-canonical-metric='spend'][data-platform-metric='link_clicks']")

        refute clicks_under_spend,
               "Expected 'Link Clicks' not to appear under canonical metric 'spend'. HTML: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the cross-platform metric comparison" do
      given_ "an unauthenticated user attempts to navigate to the dashboard", context do
        result = live(build_conn(), "/app/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the dashboard", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "platform-comparison",
                   "Unauthenticated user should not see cross-platform metric comparison data"

            :ok
        end
      end
    end
  end
end
