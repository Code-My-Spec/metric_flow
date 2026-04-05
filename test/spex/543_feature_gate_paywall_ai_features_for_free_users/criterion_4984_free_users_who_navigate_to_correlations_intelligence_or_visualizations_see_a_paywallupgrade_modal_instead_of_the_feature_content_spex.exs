defmodule MetricFlowSpex.FreeUsersSeePaswallOnAiFeaturesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Free users who navigate to correlations, intelligence, or visualizations see a paywall/upgrade modal instead of the feature content" do
    scenario "free user navigates to correlations and sees an upgrade prompt instead of correlation data" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the correlations page", context do
        result = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user sees a paywall or upgrade prompt instead of correlation feature content", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_paywall =
              has_element?(view, "[data-role='paywall']") or
                has_element?(view, "[data-role='upgrade-modal']") or
                has_element?(view, "[data-role='upgrade-prompt']") or
                html =~ "upgrade" or
                html =~ "Upgrade" or
                html =~ "paywall" or
                html =~ "Paywall" or
                html =~ "subscribe" or
                html =~ "Subscribe" or
                html =~ "paid plan" or
                html =~ "Paid plan"

            assert has_paywall,
                   "Expected a paywall or upgrade prompt on /correlations for free user. Got: #{html}"

            :ok

          {:error, {:redirect, %{to: "/subscriptions/checkout"}}} ->
            :ok

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected redirect to upgrade/checkout, got redirect to #{path}"

            :ok

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected live-redirect to upgrade/checkout, got live-redirect to #{path}"

            :ok
        end
      end
    end
  end
end
