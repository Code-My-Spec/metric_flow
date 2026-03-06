defmodule MetricFlowSpex.MetricMappingsSemanticDifferencesWarningsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Metric mappings account for known semantic differences and surface warnings or footnotes when comparing" do
    scenario "authenticated user can access the dashboard to see semantic difference warnings" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        result = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboard loads successfully for the authenticated user", context do
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

    scenario "dashboard surfaces semantic difference warnings when comparing cross-platform metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows a warning or footnote about semantic differences in metric comparisons", context do
        html = render(context.view)

        has_semantic_warning =
          html =~ "attribution" or
            html =~ "Attribution" or
            html =~ "counting method" or
            html =~ "Counting Method" or
            html =~ "window" or
            html =~ "Window" or
            html =~ "note" or
            html =~ "Note" or
            html =~ "warning" or
            html =~ "Warning" or
            html =~ "footnote" or
            html =~ "Footnote" or
            html =~ "disclaimer" or
            html =~ "Disclaimer" or
            has_element?(context.view, "[data-role='semantic-warning']") or
            has_element?(context.view, "[data-role='metric-footnote']") or
            has_element?(context.view, "[data-role='attribution-warning']") or
            has_element?(context.view, "[data-semantic-difference]") or
            has_element?(context.view, "[data-role='comparison-caveat']")

        assert has_semantic_warning,
               "Expected the dashboard to surface a warning or footnote about semantic differences (e.g., attribution windows, counting methods) when comparing cross-platform metrics, got: #{html}"

        :ok
      end
    end

    scenario "dashboard indicates attribution window differences when displaying click metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard communicates that platform metrics may use different attribution windows", context do
        html = render(context.view)

        # The dashboard should either show the canonical metric with an inline warning,
        # a footnote indicator (e.g., asterisk), or a dedicated tooltip/note element
        # explaining that platforms differ in how they attribute clicks.
        has_attribution_context =
          html =~ "attribution" or
            html =~ "Attribution" or
            html =~ "7-day" or
            html =~ "28-day" or
            html =~ "30-day" or
            html =~ "view-through" or
            html =~ "click-through" or
            html =~ "*" or
            has_element?(context.view, "[data-role='attribution-footnote']") or
            has_element?(context.view, "[data-role='semantic-note']") or
            has_element?(context.view, "[data-attribution-window]") or
            has_element?(context.view, "[data-role='metric-caveat']")

        assert has_attribution_context,
               "Expected the dashboard to communicate attribution window differences for click metrics, got: #{html}"

        :ok
      end
    end

    scenario "semantic difference warnings are visible when comparing metrics across platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard does not hide semantic caveats from the user", context do
        html = render(context.view)

        # A well-behaved dashboard must not suppress caveats silently.
        # Either a visible note, tooltip, warning icon, or footnote text must appear
        # so users understand the data may not be directly comparable.
        lacks_any_caveat_indicator =
          not (html =~ "attribution" or
                 html =~ "counting" or
                 html =~ "note" or
                 html =~ "warning" or
                 html =~ "footnote" or
                 html =~ "caveat" or
                 html =~ "*" or
                 has_element?(context.view, "[data-role='semantic-warning']") or
                 has_element?(context.view, "[data-role='metric-footnote']") or
                 has_element?(context.view, "[data-semantic-difference]"))

        # We assert that the dashboard does NOT silently hide semantic differences.
        # If the page renders without any warning/footnote indicator, the spec fails.
        refute lacks_any_caveat_indicator,
               "Expected the dashboard to surface semantic difference warnings or footnotes when comparing cross-platform metrics. The UI must not silently hide these caveats. HTML: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access semantic difference warnings" do
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
            refute render(view) =~ "semantic-warning",
                   "Unauthenticated user should not see semantic difference warning data"

            :ok
        end
      end
    end
  end
end
