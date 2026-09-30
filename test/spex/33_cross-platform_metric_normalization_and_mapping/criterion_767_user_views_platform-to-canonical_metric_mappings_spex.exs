defmodule MetricFlowSpex.UserViewsPlatformToCanonicalMetricMappingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User views platform-to-canonical metric mappings", criterion: 767 do
    scenario "a user opens the metric mappings view and sees native names alongside canonical metrics" do
      given_(:user_logged_in_as_owner)

      given_ "a user viewing the metric mapping list", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        {:ok, dashboard_view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :dashboard_view, dashboard_view)}
      end

      when_ "they open the mappings view", context do
        {:ok, context}
      end

      then_ "they see each platform's native metric name alongside the canonical metric it maps to",
            context do
        has_mappings_link =
          has_element?(context.dashboard_view, "[data-role='metric-mappings-link']") or
            has_element?(context.dashboard_view, "a[href*='mappings']")

        if has_mappings_link do
          {:ok, context}
        else
          flunk(
            "No metric mappings view exists: there is no way for a user to see each " <>
              "platform's native metric name alongside the canonical metric it maps to. " <>
              "NormalizedMetric.mapping_for/1 has the data, but nothing in the UI exposes it."
          )
        end
      end
    end
  end
end
