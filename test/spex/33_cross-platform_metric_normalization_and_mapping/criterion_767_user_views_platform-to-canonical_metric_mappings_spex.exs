defmodule MetricFlowSpex.UserViewsPlatformToCanonicalMetricMappingsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "User views platform-to-canonical metric mappings", criterion: 767 do
    scenario "a user opens the metric mappings panel and sees native names alongside canonical metrics" do
      given_(:user_logged_in_as_owner)

      given_ "a user viewing the metric mapping list", context do
        MetricFlowSpex.Fixtures.create_integration_for(context.owner_email, :google_ads)

        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "they open the mappings view", context do
        context.view
        |> element("[data-role='metric-mappings-link']")
        |> render_click()

        {:ok, context}
      end

      then_ "they see each platform's native metric name alongside the canonical metric it maps to",
            context do
        assert has_element?(
                 context.view,
                 "[data-role='metric-mapping'][data-native-name='clicks'][data-canonical-name='clicks']"
               ),
               "Expected a mappings panel listing each platform's native metric name alongside the canonical metric it maps to"

        {:ok, context}
      end
    end
  end
end
