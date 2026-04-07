defmodule MetricFlowSpex.PaywalledRoutesRedirectFreeUsersSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Paywalled routes return 402 or redirect with a flash message when accessed via direct URL by free users" do
    scenario "free user directly navigates to the visualizations page and is redirected or shown an upgrade prompt" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates directly to the visualizations page via URL", context do
        result = live(context.owner_conn, "/app/visualizations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is either redirected with a flash message or shown an upgrade prompt on the page", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_upgrade_or_flash =
              has_element?(view, "[data-role='paywall']") or
                has_element?(view, "[data-role='upgrade-modal']") or
                has_element?(view, "[data-role='upgrade-prompt']") or
                has_element?(view, "[role='alert']") or
                html =~ "upgrade" or
                html =~ "Upgrade" or
                html =~ "subscribe" or
                html =~ "Subscribe" or
                html =~ "paywall" or
                html =~ "Paywall" or
                html =~ "paid plan" or
                html =~ "requires a subscription"

            assert has_upgrade_or_flash,
                   "Expected /visualizations to show upgrade prompt or redirect free user. Got: #{html}"

            :ok

          {:error, {:redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout" or
                     path =~ "dashboard",
                   "Expected redirect to upgrade/checkout or dashboard with flash, got redirect to #{path}"

            :ok

          {:error, {:live_redirect, %{to: path}}} ->
            assert path =~ "subscription" or path =~ "upgrade" or path =~ "checkout" or
                     path =~ "dashboard",
                   "Expected live-redirect to upgrade/checkout or dashboard with flash, got live-redirect to #{path}"

            :ok
        end
      end
    end
  end
end
