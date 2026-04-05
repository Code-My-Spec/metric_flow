defmodule MetricFlowSpex.RequireSubscriptionReusableSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "A helper function or plug (e.g. require_subscription) is reusable across all paywalled routes" do
    scenario "free user navigating to the intelligence page also sees the same upgrade prompt as correlations" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the intelligence (insights) page", context do
        result = live(context.owner_conn, "/insights")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user sees an upgrade prompt on the intelligence page, confirming the same gate is applied", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_paywall =
              has_element?(view, "[data-role='paywall']") or
                has_element?(view, "[data-role='upgrade-modal']") or
                has_element?(view, "[data-role='upgrade-prompt']") or
                html =~ "upgrade" or
                html =~ "Upgrade" or
                html =~ "subscribe" or
                html =~ "Subscribe" or
                html =~ "paywall" or
                html =~ "Paywall"

            assert has_paywall,
                   "Expected the same upgrade/paywall prompt on /insights as on /correlations. Got: #{html}"

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
