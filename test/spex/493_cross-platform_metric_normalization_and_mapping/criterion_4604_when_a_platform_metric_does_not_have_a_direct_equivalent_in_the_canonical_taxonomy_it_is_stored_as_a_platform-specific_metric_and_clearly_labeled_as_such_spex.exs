defmodule MetricFlowSpex.PlatformSpecificMetricLabeledAsNonCanonicalSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "When a platform metric has no canonical equivalent it is stored and labeled as platform-specific" do
    scenario "dashboard loads for user with integrations" do
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

    scenario "dashboard clearly labels any platform-specific metrics that have no canonical equivalent" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard uses a visual label or marker to distinguish platform-specific metrics", context do
        html = render(context.view)

        # Platform-specific metrics with no canonical equivalent should be labeled clearly.
        # The UI should use one of: a "platform-specific" text label, a data attribute,
        # or a dedicated section header that distinguishes them from canonical metrics.
        has_platform_specific_label =
          html =~ "platform-specific" or
            html =~ "Platform-Specific" or
            html =~ "Platform Specific" or
            has_element?(context.view, "[data-metric-type='platform_specific']") or
            has_element?(context.view, "[data-metric-type='platform-specific']") or
            has_element?(context.view, "[data-role='platform-specific-metric']") or
            has_element?(context.view, "[data-canonical='false']") or
            has_element?(context.view, "[data-semantic-difference]")

        assert has_platform_specific_label,
               "Expected the dashboard to label non-canonical metrics as platform-specific using visible text or a data attribute. Got: #{html}"

        :ok
      end
    end

    scenario "platform-specific metrics are visually distinct from canonical metrics on the dashboard" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders a section or grouping that separates platform-specific metrics from canonical metrics", context do
        html = render(context.view)

        # The page must visually separate platform-specific metrics from canonical ones.
        # Acceptable signals: a separate section heading, a "platform-only" badge/tag,
        # a dedicated container with a data attribute, or a help-text note.
        has_separation =
          html =~ "platform-specific" or
            html =~ "Platform-Specific" or
            html =~ "Platform Specific" or
            html =~ "platform only" or
            html =~ "Platform Only" or
            has_element?(context.view, "[data-section='platform-specific-metrics']") or
            has_element?(context.view, "[data-role='platform-specific-metrics-section']") or
            has_element?(context.view, "[data-role='platform-specific-metric']") or
            has_element?(context.view, "[data-metric-type='platform_specific']") or
            has_element?(context.view, "[data-canonical='false']") or
            has_element?(context.view, "[data-semantic-difference]")

        assert has_separation,
               "Expected the dashboard to visually separate or group platform-specific metrics from canonical metrics. Got: #{html}"

        :ok
      end
    end

    scenario "platform-specific metrics display their originating platform alongside their label" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard references the originating platform when showing a platform-specific metric", context do
        html = render(context.view)

        # Platform-specific metrics should always surface the platform they came from
        # so users understand why the metric has no cross-platform equivalent.
        has_platform_context =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            html =~ "QuickBooks" or
            html =~ "quickbooks" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']")

        assert has_platform_context,
               "Expected the dashboard to show the originating platform alongside platform-specific metrics. Got: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access platform-specific metric information" do
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
            refute render(view) =~ "platform-specific"
            :ok
        end
      end
    end
  end
end
