defmodule MetricFlowSpex.GoalMetricsAccessFromMenuSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "User can access Goal Metrics configuration from menu" do
    scenario "authenticated user navigates to the goal metrics page" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the correlations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a link to configure goal metrics", context do
        html = render(context.view)

        has_goal_link =
          has_element?(context.view, "[data-role='configure-goals']") or
            has_element?(context.view, "a[href='/correlations/goals']") or
            html =~ "Goal Metrics" or
            html =~ "Configure Goals" or
            html =~ "Set Goals"

        assert has_goal_link,
               "Expected a link or button to access Goal Metrics configuration. Got: #{html}"

        :ok
      end
    end

    scenario "user accesses goal metrics configuration page directly" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the goal metrics configuration page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations/goals")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the goal metrics configuration page is displayed", context do
        html = render(context.view)

        assert html =~ "Goal" or html =~ "goal",
               "Expected the goal metrics page to display goal-related content. Got: #{html}"

        :ok
      end
    end
  end
end
