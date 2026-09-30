defmodule MetricFlowSpex.NoConnectedIntegrationsShowsOnboardingPromptsSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "No connected integrations shows onboarding prompts", criterion: 753 do
    scenario "a client with no integrations connected sees onboarding prompts instead of empty charts" do
      given_(:user_logged_in_as_owner)

      when_ "they open the dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "onboarding prompts are shown instead of empty charts", context do
        assert has_element?(context.view, "[data-role='onboarding-prompt']")
        refute has_element?(context.view, "[data-role='multi-series-chart']")
        {:ok, context}
      end
    end
  end
end
