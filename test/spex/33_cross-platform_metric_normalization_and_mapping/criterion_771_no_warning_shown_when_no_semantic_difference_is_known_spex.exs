defmodule MetricFlowSpex.NoWarningShownWhenNoSemanticDifferenceIsKnownSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "No warning shown when no semantic difference is known", criterion: 771 do
    scenario "a single-platform metric with no cross-platform comparison shows no semantic-difference warning" do
      given_(:user_logged_in_as_owner)

      given_ "a platform metric mapped to a canonical metric with no known semantic difference to compare against",
             context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        MetricFlowSpex.Fixtures.create_metric_for(context.owner_email, %{
          provider: :google_ads,
          metric_name: "clicks",
          value: 30.0
        })

        {:ok, context}
      end

      when_ "a user views that metric", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "no warning or footnote is displayed", context do
        refute has_element?(context.view, "[data-role='semantic-warning']"),
               "Expected no semantic-difference warning when there is no cross-platform comparison to warn about"

        {:ok, context}
      end
    end
  end
end
