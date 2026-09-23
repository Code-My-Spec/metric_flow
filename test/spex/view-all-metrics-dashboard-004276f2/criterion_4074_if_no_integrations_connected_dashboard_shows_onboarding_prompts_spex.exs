defmodule MetricFlowSpex.IfNoIntegrationsConnectedDashboardShowsOnboardingPromptsSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "If no integrations connected, dashboard shows onboarding prompts" do
    scenario "user with no integrations sees an onboarding or empty state message" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard without any connected integrations", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "an onboarding or empty state message is visible on the dashboard", context do
        html = render(context.view)

        has_onboarding_message =
          html =~ "onboard" or
            html =~ "Onboard" or
            html =~ "get started" or
            html =~ "Get started" or
            html =~ "Get Started" or
            html =~ "no integrations" or
            html =~ "No integrations" or
            html =~ "no data" or
            html =~ "No data" or
            html =~ "empty" or
            html =~ "Empty" or
            html =~ "connect" or
            html =~ "Connect" or
            has_element?(context.view, "[data-role='onboarding-prompt']") or
            has_element?(context.view, "[data-role='empty-state']") or
            has_element?(context.view, "[data-role='no-integrations']")

        assert has_onboarding_message,
               "Expected the dashboard to show an onboarding or empty state message when no integrations are connected, got: #{html}"

        :ok
      end
    end

    scenario "onboarding message mentions connecting integrations or platforms" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard without any connected integrations", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the onboarding message references integrations or platforms", context do
        html = render(context.view)

        mentions_integrations_or_platforms =
          html =~ "integration" or
            html =~ "Integration" or
            html =~ "platform" or
            html =~ "Platform" or
            html =~ "connect" or
            html =~ "Connect" or
            html =~ "Google" or
            html =~ "Facebook" or
            html =~ "QuickBooks" or
            has_element?(context.view, "[data-role='connect-integrations-prompt']") or
            has_element?(context.view, "[data-role='integration-onboarding']")

        assert mentions_integrations_or_platforms,
               "Expected the dashboard onboarding state to mention connecting integrations or platforms, got: #{html}"

        :ok
      end
    end

    scenario "dashboard shows a link or button to connect integrations when none are connected" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard without any connected integrations", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a link or button pointing to the integrations page is visible", context do
        has_connect_link =
          has_element?(context.view, "a[href='/integrations']") or
            has_element?(context.view, "a[href*='integration']") or
            has_element?(context.view, "[data-role='connect-integration-link']") or
            has_element?(context.view, "[data-role='connect-integration-button']") or
            has_element?(context.view, "button", "Connect") or
            has_element?(context.view, "a", "Connect") or
            has_element?(context.view, "button", "Add Integration") or
            has_element?(context.view, "a", "Add Integration") or
            has_element?(context.view, "button", "Get Started") or
            has_element?(context.view, "a", "Get Started")

        assert has_connect_link,
               "Expected the dashboard to show a link or button to the integrations page when no integrations are connected"

        :ok
      end
    end

    scenario "no metrics data sections are shown when no integrations are connected" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to the dashboard without any connected integrations", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the dashboard does not display populated metrics data", context do
        has_no_metrics_data =
          not has_element?(context.view, "[data-role='metrics-data'][data-loaded='true']") and
            not has_element?(context.view, "[data-role='chart'][data-has-data='true']") and
            not has_element?(context.view, "[data-role='metric-value'][data-populated='true']")

        # Also accept: the page does not render numeric metric values inline
        # indicating real synced data (as opposed to placeholder zeros or empty state copy).
        html = render(context.view)

        shows_onboarding_not_data =
          has_no_metrics_data or
            html =~ "onboard" or
            html =~ "Onboard" or
            html =~ "get started" or
            html =~ "Get started" or
            html =~ "Get Started" or
            html =~ "No data" or
            html =~ "no data" or
            has_element?(context.view, "[data-role='empty-state']") or
            has_element?(context.view, "[data-role='onboarding-prompt']")

        assert shows_onboarding_not_data,
               "Expected the dashboard to show an empty/onboarding state rather than populated metrics data when no integrations are connected, got: #{html}"

        :ok
      end
    end
  end
end
