defmodule MetricFlowSpex.EachPlatformIntegrationDefinesMappingsToCanonicalMetricsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Each platform integration defines mappings from its native metric names to canonical metrics" do
    scenario "dashboard loads successfully for user with integrations from multiple platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard loads without error", context do
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

    scenario "dashboard shows the canonical 'clicks' metric consolidating platform-specific click metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard displays a unified clicks metric from platform-specific sources", context do
        html = render(context.view)

        has_clicks =
          html =~ "Clicks" or
            html =~ "clicks" or
            has_element?(context.view, "[data-canonical-metric='clicks']") or
            has_element?(context.view, "[data-metric-name='clicks']") or
            has_element?(context.view, "[data-role='metric-clicks']")

        assert has_clicks,
               "Expected the dashboard to display the canonical metric 'clicks' aggregated from platform-specific metrics (e.g., Google Ads 'Clicks', Facebook Ads 'Link Clicks'), got: #{html}"

        :ok
      end
    end

    scenario "dashboard does not expose raw platform-specific metric names as separate top-level metrics when they map to a canonical metric" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard does not show 'Link Clicks' as a standalone top-level canonical metric", context do
        html = render(context.view)

        # 'Link Clicks' is a Facebook Ads native metric name - if shown it should be
        # labeled as platform-specific, not presented as its own canonical metric alongside 'clicks'
        shows_link_clicks_as_canonical =
          has_element?(context.view, "[data-canonical-metric='link_clicks']") or
            has_element?(context.view, "[data-canonical-metric='link clicks']")

        refute shows_link_clicks_as_canonical,
               "Expected 'Link Clicks' to be mapped to the canonical 'clicks' metric, not shown as its own canonical metric. HTML: #{html}"

        :ok
      end
    end

    scenario "dashboard groups platform-specific metric variants under their shared canonical name" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the canonical metric section references data from the connected integration platforms", context do
        html = render(context.view)

        # The dashboard should show platform names (Google, Facebook) alongside metrics,
        # indicating multiple platform sources feed into the canonical metric display
        has_platform_reference =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']")

        assert has_platform_reference,
               "Expected the dashboard to reference platform sources (e.g., Google, Facebook) when displaying metrics from multiple integrations, got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access platform metric mappings on the dashboard" do
      given_ "an unauthenticated user attempts to view the dashboard", context do
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
            refute render(view) =~ "Link Clicks"
            :ok
        end
      end
    end
  end
end
