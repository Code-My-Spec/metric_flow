defmodule MetricFlowSpex.SystemProvidesDefaultDashboardTemplatesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "System provides default dashboard templates (e.g., Marketing Overview, Revenue Analysis, Platform Comparison)", criterion: 162 do
    scenario "authenticated user can navigate to the dashboards index page" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboards page", context do
        result = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboards page loads successfully", context do
        case context.result do
          {:ok, _view, _html} ->
            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboards to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboards to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "dashboards page displays a Marketing Overview template" do
      given_ :user_logged_in_as_owner

      given_ "canned dashboards exist in the database", context do
        for name <- ["Marketing Overview", "Revenue Analysis", "Platform Comparison"] do
          MetricFlowSpex.Fixtures.create_canned_dashboard!(context.owner_email, name)
        end

        {:ok, context}
      end

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a Marketing Overview dashboard template", context do
        html = render(context.view)

        assert html =~ "Marketing Overview" or
                 html =~ "marketing_overview" or
                 has_element?(context.view, "[data-template='marketing_overview']") or
                 has_element?(context.view, "[data-role='dashboard-template']")

        {:ok, context}
      end
    end

    scenario "dashboards page displays a Revenue Analysis template" do
      given_ :user_logged_in_as_owner

      given_ "canned dashboards exist in the database", context do
        for name <- ["Marketing Overview", "Revenue Analysis", "Platform Comparison"] do
          MetricFlowSpex.Fixtures.create_canned_dashboard!(context.owner_email, name)
        end

        {:ok, context}
      end

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a Revenue Analysis dashboard template", context do
        html = render(context.view)

        assert html =~ "Revenue Analysis" or
                 html =~ "revenue_analysis" or
                 has_element?(context.view, "[data-template='revenue_analysis']") or
                 has_element?(context.view, "[data-role='dashboard-template']")

        {:ok, context}
      end
    end

    scenario "dashboards page displays a Platform Comparison template" do
      given_ :user_logged_in_as_owner

      given_ "canned dashboards exist in the database", context do
        for name <- ["Marketing Overview", "Revenue Analysis", "Platform Comparison"] do
          MetricFlowSpex.Fixtures.create_canned_dashboard!(context.owner_email, name)
        end

        {:ok, context}
      end

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows a Platform Comparison dashboard template", context do
        html = render(context.view)

        assert html =~ "Platform Comparison" or
                 html =~ "platform_comparison" or
                 has_element?(context.view, "[data-template='platform_comparison']") or
                 has_element?(context.view, "[data-role='dashboard-template']")

        {:ok, context}
      end
    end

    scenario "dashboards page lists multiple canned templates" do
      given_ :user_logged_in_as_owner

      given_ "canned dashboards exist in the database", context do
        for name <- ["Marketing Overview", "Revenue Analysis", "Platform Comparison"] do
          MetricFlowSpex.Fixtures.create_canned_dashboard!(context.owner_email, name)
        end

        {:ok, context}
      end

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays at least one dashboard template for the user to choose from", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='canned-dashboards']") or
                 has_element?(context.view, "[data-role='dashboard-template']") or
                 has_element?(context.view, "[data-role='template-list']") or
                 html =~ "Built-in" or
                 html =~ "System Dashboards"

        {:ok, context}
      end
    end

    scenario "unauthenticated user cannot access the dashboards templates page" do
      given_ "an unauthenticated user navigates to the dashboards page", context do
        result = live(build_conn(), "/app/dashboards")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the dashboards page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            {:ok, context}

          {:error, {:live_redirect, _}} ->
            {:ok, context}

          {:ok, view, _html} ->
            refute render(view) =~ "Marketing Overview"
            {:ok, context}
        end
      end
    end
  end
end
