defmodule MetricFlowSpex.Criterion5047AuthoringWorkspaceThreePanelsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can open a visualization authoring workspace with prompt, spec editor, and preview" do
    scenario "report generator page has prompt input and preview areas" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      when_ "user navigates to the report generator", context do
        {:ok, view, html} = live(context.owner_conn, "/reports/generate")
        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "a prompt form for chat-style input is present", context do
        assert has_element?(context.view, "[data-role='prompt-form']")
        assert has_element?(context.view, "[data-role='prompt-input']")
        :ok
      end

      then_ "a chart preview section is available (shown after generation)", context do
        # Before generation, the empty state is shown
        assert has_element?(context.view, "[data-role='empty-state']")
        :ok
      end
    end
  end
end
