defmodule MetricFlowSpex.FeatureGateEnforcedServerSideSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Feature access is enforced server-side: gating cannot be bypassed by manipulating client state" do
    scenario "free user navigating to correlations does not receive correlation data in the rendered page" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the correlations page", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the page does not render correlation data for the free user", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            renders_correlation_data =
              has_element?(view, "[data-role='correlation-results']") and
                not (has_element?(view, "[data-role='paywall']") or
                       has_element?(view, "[data-role='upgrade-modal']") or
                       has_element?(view, "[data-role='upgrade-prompt']"))

            refute renders_correlation_data,
                   "Expected correlation data NOT to be rendered for free users (server-side gate). Got: #{html}"

            :ok

          {:error, {:redirect, _}} ->
            :ok

          {:error, {:live_redirect, _}} ->
            :ok
        end
      end
    end
  end
end
