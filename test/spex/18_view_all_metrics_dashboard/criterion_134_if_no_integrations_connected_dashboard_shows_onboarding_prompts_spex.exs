defmodule MetricFlowSpex.IfNoIntegrationsConnectedDashboardShowsOnboardingPromptsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "If no integrations connected, dashboard shows onboarding prompts", criterion: 134 do
    scenario "a client with no connected integrations sees onboarding prompts instead of empty charts" do
      given_(:user_logged_in_as_owner)

      when_ "they open the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "onboarding prompts are shown", context do
        assert has_element?(context.view, "[data-role='onboarding-prompt']")
        assert render(context.view) =~ "Connect Your Platforms"
        {:ok, context}
      end

      then_ "the metrics dashboard itself is not shown", context do
        refute has_element?(context.view, "[data-role='metrics-dashboard']")
        {:ok, context}
      end
    end
  end
end
