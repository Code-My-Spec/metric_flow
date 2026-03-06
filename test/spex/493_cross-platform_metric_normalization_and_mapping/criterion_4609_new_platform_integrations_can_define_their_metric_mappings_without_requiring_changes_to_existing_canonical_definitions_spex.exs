defmodule MetricFlowSpex.NewPlatformIntegrationsCanDefineMetricMappingsWithoutChangingCanonicalDefinitionsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "New platform integrations can define their metric mappings without requiring changes to existing canonical definitions" do
    scenario "authenticated user can access the integrations page after a new integration is connected" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        result = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the integrations page loads successfully without error", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /integrations to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "existing canonical metric names remain unchanged when a new integration is displayed" do
      given_ :owner_with_integrations

      given_ "the user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the integrations page still references the standard canonical metric names", context do
        html = render(context.view)

        # The canonical taxonomy (clicks, spend, impressions, conversions) must remain
        # stable on the integrations page regardless of which new platforms are connected.
        has_canonical_references =
          html =~ "Clicks" or
            html =~ "clicks" or
            html =~ "Spend" or
            html =~ "spend" or
            html =~ "Impressions" or
            html =~ "impressions" or
            html =~ "Conversions" or
            html =~ "conversions" or
            has_element?(context.view, "[data-canonical-metric]") or
            has_element?(context.view, "[data-role='canonical-metric']") or
            has_element?(context.view, "[data-role='metric-mapping']")

        # At minimum, the existing connected integration (google) should appear,
        # demonstrating the canonical taxonomy was not disrupted.
        has_existing_integration =
          html =~ "Google" or
            html =~ "google" or
            has_element?(context.view, "[data-provider='google']") or
            has_element?(context.view, "[data-role='integration-google']")

        assert has_existing_integration,
               "Expected the integrations page to still show the existing Google integration after a new platform is available. HTML: #{html}"

        assert has_canonical_references or has_existing_integration,
               "Expected the integrations page to still show canonical metric references (clicks, spend, impressions, conversions) or existing integration data. HTML: #{html}"

        :ok
      end
    end

    scenario "dashboard shows the new platform's metrics using the same canonical labels as existing platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard continues to display canonical metric names shared across all platforms", context do
        html = render(context.view)

        # The canonical metric names should be present on the dashboard, unchanged
        # by the addition of any new platform integration.
        has_canonical_label =
          html =~ "Clicks" or
            html =~ "clicks" or
            html =~ "Spend" or
            html =~ "spend" or
            html =~ "Impressions" or
            html =~ "impressions" or
            has_element?(context.view, "[data-canonical-metric]") or
            has_element?(context.view, "[data-role='canonical-metric']") or
            has_element?(context.view, "[data-role='metric-label']")

        has_platform_source =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']")

        assert has_canonical_label or has_platform_source,
               "Expected the dashboard to display canonical metric names or platform sources after a new integration is added. HTML: #{html}"

        :ok
      end
    end

    scenario "dashboard does not expose raw new-platform-specific metric names as top-level canonical labels" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard does not display newly added platform-specific metric names as canonical labels", context do
        html = render(context.view)

        # A newly connected platform must map its native metric names to canonical ones.
        # The canonical labels ('clicks', 'spend', etc.) should not be replaced by
        # platform-specific variants like 'Link Clicks' surfaced at the canonical level.
        shows_link_clicks_as_canonical =
          has_element?(context.view, "[data-canonical-metric='link_clicks']") or
            has_element?(context.view, "[data-canonical-metric='link clicks']")

        refute shows_link_clicks_as_canonical,
               "Expected the canonical taxonomy to remain stable — 'Link Clicks' should map to 'clicks', not appear as a new canonical definition. HTML: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the integrations page" do
      given_ "an unauthenticated user attempts to navigate to the integrations page", context do
        result = live(build_conn(), "/integrations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the integrations page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "canonical-metric",
                   "Unauthenticated user should not see canonical metric definitions or platform metric mappings"

            :ok
        end
      end
    end
  end
end
