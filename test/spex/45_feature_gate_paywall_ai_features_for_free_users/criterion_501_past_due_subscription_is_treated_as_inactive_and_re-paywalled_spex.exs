defmodule MetricFlowSpex.PastDueSubscriptionIsTreatedAsInactiveAndRePaywalledSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Past_due subscription is treated as inactive and re-paywalled", criterion: 501 do
    scenario "Dana's subscription status changes from subscribed to past_due" do
      given_ :user_logged_in_as_owner
      given_ :owner_subscription_past_due

      when_ "Dana navigates to Correlations", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "she sees the paywall/upgrade modal again instead of the feature content", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_paywall =
              has_element?(view, "[data-role='paywall']") or
                has_element?(view, "[data-role='upgrade-modal']") or
                html =~ "upgrade" or html =~ "Upgrade" or
                html =~ "paywall" or html =~ "Paywall"

            assert has_paywall,
                   "Expected a past_due subscription to be re-paywalled on /correlations. Got: #{html}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected redirect to upgrade/checkout, got redirect to #{path}"

            {:ok, context}

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected live-redirect to upgrade/checkout, got live-redirect to #{path}"

            {:ok, context}
        end
      end
    end
  end
end
