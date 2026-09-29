defmodule MetricFlowSpex.DirectUrlAccessToAPaywalledRouteIsBlockedForFreeUsersSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Direct URL access to a paywalled route is blocked for free users", criterion: 504 do
    scenario "Dana pastes the direct URL for Visualizations into her browser" do
      given_ :user_logged_in_as_owner

      when_ "she pastes the direct URL for Visualizations into her browser", context do
        result = live(context.owner_conn, "/app/visualizations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "she receives a 402 response or is redirected with a flash message instead of seeing the page",
            context do
        case context.result do
          {:error, {:redirect, %{to: path, flash: flash}}} ->
            assert map_size(flash) > 0, "Expected a flash message on redirect, got none"

            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected redirect to upgrade/checkout, got redirect to #{path}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected redirect to upgrade/checkout, got redirect to #{path}"

            {:ok, context}

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout",
                   "Expected live-redirect to upgrade/checkout, got live-redirect to #{path}"

            {:ok, context}

          {:ok, view, _html} ->
            html = render(view)

            assert html =~ "402" or has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected a 402/paywall response for direct URL access by a free user. Got: #{html}"

            {:ok, context}
        end
      end
    end
  end
end
