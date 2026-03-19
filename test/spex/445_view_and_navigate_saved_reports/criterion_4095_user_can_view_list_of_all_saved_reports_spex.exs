defmodule MetricFlowSpex.Criterion4095UserCanViewListOfAllSavedReportsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can view list of all saved reports" do
    scenario "authenticated user can navigate to the dashboards list page" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboards page", context do
        result = live(context.owner_conn, "/dashboards")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the dashboards page loads successfully", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboards to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboards to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "dashboards page shows the page heading" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page displays a heading identifying it as the dashboards section", context do
        html = render(context.view)

        assert html =~ "Dashboard" or
                 has_element?(context.view, "h1") or
                 has_element?(context.view, "[data-role='dashboards-heading']")

        :ok
      end
    end

    scenario "dashboards page shows user-owned dashboards section" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains a section for the user's own dashboards", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='user-dashboards']") or
                 html =~ "My Dashboard" or
                 html =~ "your dashboard" or
                 html =~ "Your dashboard" or
                 has_element?(context.view, "[data-role='empty-user-dashboards']")

        :ok
      end
    end

    scenario "dashboards page shows system canned dashboards section" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboards page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page contains a section for system-provided dashboards", context do
        html = render(context.view)

        assert has_element?(context.view, "[data-role='canned-dashboards']") or
                 html =~ "System Dashboard" or
                 html =~ "Built-in" or
                 html =~ "built-in" or
                 html =~ "Pre-built" or
                 html =~ "pre-built"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the dashboards list" do
      given_ "an unauthenticated user navigates to the dashboards page", context do
        result = live(build_conn(), "/dashboards")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the dashboards page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "My Dashboards"
            :ok
        end
      end
    end
  end
end
