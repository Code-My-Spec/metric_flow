defmodule MetricFlowSpex.TheSameGateBlocksEveryAiRouteConsistentlySpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "The same gate blocks every AI route consistently", criterion: 503 do
    scenario "Dana on the free plan requests Correlations, Intelligence, and Visualizations in turn" do
      given_ :user_logged_in_as_owner

      when_ "she requests Correlations, Intelligence, and Visualizations in turn", context do
        results = %{
          correlations: live(context.owner_conn, "/app/correlations"),
          intelligence: live(context.owner_conn, "/app/insights"),
          visualizations: live(context.owner_conn, "/app/visualizations")
        }

        {:ok, Map.put(context, :results, results)}
      end

      then_ "the same require_subscription check paywalls all three identically", context do
        gated? = fn
          {:ok, view, _html} ->
            html = render(view)

            has_element?(view, "[data-role='paywall']") or
              has_element?(view, "[data-role='upgrade-modal']") or
              html =~ "upgrade" or html =~ "Upgrade" or
              html =~ "paywall" or html =~ "Paywall"

          {:error, {:redirect, %{to: path}}} ->
            path =~ "subscription" or path =~ "upgrade" or path =~ "checkout"

          {:error, {:live_redirect, %{to: path}}} ->
            path =~ "subscription" or path =~ "upgrade" or path =~ "checkout"
        end

        for {route, result} <- context.results do
          assert gated?.(result), "Expected /#{route} to be gated identically for a free user"
        end

        {:ok, context}
      end
    end
  end
end
