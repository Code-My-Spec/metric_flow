defmodule MetricFlowSpex.NoWarningShownWhenNoSemanticDifferenceIsKnownSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "No warning shown when no semantic difference is known", criterion: 771 do
    scenario "a user with no connected platforms sees no semantic-difference warning" do
      given_ :user_logged_in_as_owner

      given_ "no platform has been connected, so there is no comparison to warn about", context do
        {:ok, context}
      end

      when_ "they view the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no semantic-difference warning or footnote is displayed", context do
        refute has_element?(context.view, "[data-role='semantic-warning']"),
               "Expected no semantic-difference warning when there are no connected platforms to compare"

        {:ok, context}
      end
    end
  end
end
