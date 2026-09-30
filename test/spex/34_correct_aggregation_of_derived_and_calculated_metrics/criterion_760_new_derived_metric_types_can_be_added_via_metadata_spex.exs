defmodule MetricFlowSpex.NewDerivedMetricTypesCanBeAddedViaMetadataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "New derived metric types can be added via metadata", criterion: 760 do
    scenario "a new derived metric type defined as metadata becomes available for aggregation without engine code changes" do
      given_(:user_logged_in_as_owner)

      given_ "the client is on a page where derived metrics could be configured", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a new derived metric type with its own formula is defined as metadata and added to the system",
            context do
        {:ok, context}
      end

      then_ "it is available for aggregation without changing the aggregation engine's code",
            context do
        refute has_element?(context.view, "[data-role='define-derived-metric']"),
               "Expected no UI to add a new derived metric type -- confirming there is no metadata-driven extension point"

        flunk(
          "No metadata-driven way to add a new derived metric type exists; " <>
            "derived metrics are a hardcoded module attribute (@known_derived_metrics) " <>
            "in DashboardLive.Show, so adding one requires an engineer to change that code"
        )

        {:ok, context}
      end
    end
  end
end
