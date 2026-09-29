defmodule MetricFlowSpex.FreeUserSeesAPaywallInsteadOfAiFeatureContentSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Free user sees a paywall instead of AI feature content", criterion: 496 do
    scenario "Dana on the free plan navigates to Correlations" do
      given_ :user_logged_in_as_owner

      when_ "Dana navigates to Correlations", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "she sees a paywall/upgrade modal instead of the Correlations content", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_paywall =
              has_element?(view, "[data-role='paywall']") or
                has_element?(view, "[data-role='upgrade-modal']") or
                html =~ "upgrade" or html =~ "Upgrade" or
                html =~ "paywall" or html =~ "Paywall" or
                html =~ "subscribe" or html =~ "Subscribe"

            assert has_paywall,
                   "Expected a paywall/upgrade modal instead of Correlations content. Got: #{html}"

            refute has_element?(view, "[data-role='correlation-results']"),
                   "Expected Correlations content NOT to be shown to a free user"

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
