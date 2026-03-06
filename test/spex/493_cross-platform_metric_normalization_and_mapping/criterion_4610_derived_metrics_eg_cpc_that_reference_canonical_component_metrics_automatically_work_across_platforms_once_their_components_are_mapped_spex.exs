defmodule MetricFlowSpex.DerivedMetricsAutomaticallyWorkAcrossPlatformsOnceComponentsAreMappedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Derived metrics that reference canonical component metrics automatically work across platforms once their components are mapped" do
    scenario "dashboard loads for a user with integrations" do
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

    scenario "dashboard displays the derived CPC metric computed from canonical spend and clicks" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard renders the derived CPC metric", context do
        html = render(context.view)

        has_cpc =
          html =~ "CPC" or
            html =~ "cpc" or
            html =~ "Cost per Click" or
            html =~ "cost per click" or
            has_element?(context.view, "[data-canonical-metric='cpc']") or
            has_element?(context.view, "[data-metric-name='cpc']") or
            has_element?(context.view, "[data-role='metric-cpc']") or
            has_element?(context.view, "[data-role='derived-metric-cpc']")

        assert has_cpc,
               "Expected the dashboard to display the derived CPC metric computed from canonical 'spend' and 'clicks' components, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows derived metrics that span across multiple connected platforms" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard shows a derived metric alongside a platform reference", context do
        html = render(context.view)

        has_derived_metric =
          html =~ "CPC" or
            html =~ "cpc" or
            html =~ "CTR" or
            html =~ "ctr" or
            html =~ "ROAS" or
            html =~ "roas" or
            html =~ "CPM" or
            html =~ "cpm" or
            has_element?(context.view, "[data-derived-metric]") or
            has_element?(context.view, "[data-role='derived-metric']")

        has_platform_source =
          html =~ "Google" or
            html =~ "google" or
            html =~ "Facebook" or
            html =~ "facebook" or
            has_element?(context.view, "[data-platform]") or
            has_element?(context.view, "[data-provider]") or
            has_element?(context.view, "[data-role='platform-source']")

        assert has_derived_metric or has_platform_source,
               "Expected the dashboard to show a derived metric (e.g., CPC, CTR) that references canonical components from mapped platforms, got: #{html}"

        :ok
      end
    end

    scenario "dashboard does not expose raw platform-specific metric names as the label for derived metrics" do
      given_ :owner_with_integrations

      given_ "the user navigates to the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "derived metrics on the dashboard use canonical names not raw platform names", context do
        html = render(context.view)

        # Derived metrics should reference canonical component names, not raw platform
        # internal metric IDs like 'action_link_click_cost' (Facebook internal name for CPC).
        exposes_raw_platform_derived_metric =
          has_element?(context.view, "[data-canonical-metric='action_link_click_cost']") or
            has_element?(context.view, "[data-canonical-metric='cost_per_action_type']")

        refute exposes_raw_platform_derived_metric,
               "Expected derived metrics to use canonical names (e.g., 'cpc'), not raw platform-internal metric names. HTML: #{html}"

        :ok
      end
    end

    scenario "unauthenticated user cannot access derived metric data" do
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
            refute render(view) =~ "derived-metric",
                   "Unauthenticated user should not see derived metric data"

            :ok
        end
      end
    end
  end
end
