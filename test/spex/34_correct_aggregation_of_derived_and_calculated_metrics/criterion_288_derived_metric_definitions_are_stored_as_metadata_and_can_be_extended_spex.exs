defmodule MetricFlowSpex.DerivedMetricDefinitionsAreStoredAsMetadataAndCanBeExtendedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Derived metric definitions are stored as metadata and can be extended for new metric types",
    criterion: 288 do
    scenario "an agency admin can define a new derived metric type without an engineer changing the aggregation code" do
      given_(:user_logged_in_as_owner)

      given_ "the client is on a page where derived metrics are configured", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they attempt to define a new derived metric type, e.g. CPA = total_cost / conversions",
            context do
        {:ok, context}
      end

      then_ "a way to define and extend derived metrics exists without code changes", context do
        refute has_element?(context.view, "[data-role='define-derived-metric']"),
               "Expected no UI to define a new derived metric type -- confirming derived metrics are not extensible via metadata"

        flunk(
          "No metadata-driven way to define a new derived metric type exists; " <>
            "derived metrics are a hardcoded module attribute in DashboardLive.Show"
        )

        {:ok, context}
      end
    end
  end
end
