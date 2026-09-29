defmodule MetricFlowSpex.SubscribedDirectUserSeesFullAiFeatureContentSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Subscribed direct user sees full AI feature content", criterion: 499 do
    scenario "Dana has an active paid subscription and navigates to Intelligence" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_active_subscription

      when_ "she navigates to Intelligence", context do
        result = live(context.owner_conn, "/app/insights")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "she sees the full feature content with no paywall", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            refute has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected no paywall on /insights for a subscribed user. Got: #{html}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected /insights to load for a subscribed user but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected /insights to load for a subscribed user but was live-redirected to #{path}")
        end
      end
    end
  end
end
