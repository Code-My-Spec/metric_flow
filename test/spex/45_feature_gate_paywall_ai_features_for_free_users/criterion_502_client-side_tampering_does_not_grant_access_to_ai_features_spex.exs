defmodule MetricFlowSpex.ClientSideTamperingDoesNotGrantAccessToAiFeaturesSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Client-side tampering does not grant access to AI features", criterion: 502 do
    scenario "Dana on the free plan manipulates client-side state to claim a paid plan" do
      given_ :user_logged_in_as_owner

      when_ "she navigates to Visualizations while claiming a paid plan via forged request params",
            context do
        result = live(context.owner_conn, "/app/visualizations?plan=paid&subscription_status=active")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the server-side check still blocks her and she sees the paywall", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_paywall =
              has_element?(view, "[data-role='paywall']") or
                has_element?(view, "[data-role='upgrade-modal']") or
                html =~ "upgrade" or html =~ "Upgrade" or
                html =~ "paywall" or html =~ "Paywall"

            assert has_paywall,
                   "Expected forged plan/subscription params to be ignored and the paywall shown. Got: #{html}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected redirect to upgrade/checkout despite forged params, got redirect to #{path}"

            {:ok, context}

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected live-redirect to upgrade/checkout despite forged params, got live-redirect to #{path}"

            {:ok, context}
        end
      end
    end
  end
end
