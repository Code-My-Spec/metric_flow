defmodule MetricFlowSpex.Criterion4082CreateFromTemplateOrBlankSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can create new report from template or blank canvas" do
    scenario "new dashboard page shows template chooser and blank canvas option" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      when_ "user navigates to create a new dashboard", context do
        {:ok, view, html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "template options are displayed", context do
        assert has_element?(context.view, "[data-role='template-chooser']")
        assert has_element?(context.view, "[data-role='template-card-marketing_overview']")
        assert has_element?(context.view, "[data-role='template-card-financial_summary']")
        :ok
      end

      then_ "a blank canvas option is available", context do
        assert has_element?(context.view, "[data-role='template-card-blank']")
        :ok
      end
    end

    scenario "selecting a template populates the canvas with visualizations" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      given_ "user is on the new dashboard page", context do
        {:ok, view, _html} = live(context.owner_conn, "/dashboards/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user selects the marketing overview template", context do
        context.view
        |> element("[data-role='template-card-marketing_overview']")
        |> render_click()

        {:ok, context}
      end

      then_ "visualization cards are added to the canvas", context do
        assert has_element?(context.view, "[data-role='visualization-card']")
        :ok
      end
    end
  end
end
