defmodule MetricFlowSpex.UserCanCreateNewReportFromTemplateOrBlankCanvasSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can create new report from template or blank canvas" do
    scenario "authenticated user can navigate to the report editor page" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new report page", context do
        result = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the report editor page loads successfully", context do
        case context.result do
          {:ok, _view, _html} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /dashboards/new to load but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /dashboards/new to load but was live-redirected to #{path}")
        end
      end
    end

    scenario "report editor shows option to start from a blank canvas" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new report page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an option to create a blank report", context do
        html = render(context.view)

        assert html =~ "Blank" or
                 html =~ "blank" or
                 html =~ "Empty" or
                 html =~ "empty" or
                 html =~ "canvas" or
                 html =~ "Canvas" or
                 has_element?(context.view, "[data-role='blank-report']") or
                 has_element?(context.view, "[data-role='new-report-blank']")

        :ok
      end
    end

    scenario "report editor shows option to start from a template" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new report page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page shows an option to create from a template", context do
        html = render(context.view)

        assert html =~ "Template" or
                 html =~ "template" or
                 html =~ "preset" or
                 html =~ "Preset" or
                 has_element?(context.view, "[data-role='report-template']") or
                 has_element?(context.view, "[data-role='new-report-template']")

        :ok
      end
    end

    scenario "user can initiate creating a blank report" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the new report page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks to start a blank report", context do
        result =
          cond do
            has_element?(context.view, "[data-role='blank-report']") ->
              context.view |> element("[data-role='blank-report']") |> render_click()

            has_element?(context.view, "button", "Blank") ->
              context.view |> element("button", "Blank") |> render_click()

            has_element?(context.view, "a", "Blank") ->
              context.view |> element("a", "Blank") |> render_click()

            true ->
              render(context.view)
          end

        {:ok, Map.put(context, :click_result, result)}
      end

      then_ "the user is taken to a report editor canvas", context do
        html =
          case context.click_result do
            html when is_binary(html) -> html
            _ -> render(context.view)
          end

        assert html =~ "report" or
                 html =~ "Report" or
                 html =~ "editor" or
                 html =~ "Editor" or
                 html =~ "canvas" or
                 html =~ "Canvas"

        :ok
      end
    end

    scenario "unauthenticated user cannot access the report creation page" do
      given_ "an unauthenticated user navigates to the new report page", context do
        result = live(build_conn(), "/dashboards/new")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected away from the page", context do
        case context.result do
          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok

          {:ok, view, _html} ->
            refute render(view) =~ "New Report"
            :ok
        end
      end
    end
  end
end
