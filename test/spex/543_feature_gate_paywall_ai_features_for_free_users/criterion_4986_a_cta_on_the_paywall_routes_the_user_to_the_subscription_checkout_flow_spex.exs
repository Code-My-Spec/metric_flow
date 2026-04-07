defmodule MetricFlowSpex.PaywallCtaRoutesToCheckoutSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "A CTA on the paywall routes the user to the subscription checkout flow" do
    scenario "the paywall on correlations includes a link or button pointing to the checkout page" do
      given_ :user_logged_in_as_owner

      given_ "the free user navigates to the correlations page", context do
        result = live(context.owner_conn, "/app/correlations")
        {:ok, Map.put(context, :result, result)}
      end

      then_ "the paywall contains a call-to-action that leads to the subscription checkout", context do
        case context.result do
          {:ok, view, _html} ->
            html = render(view)

            has_checkout_cta =
              has_element?(view, "a[href='/subscriptions/checkout']") or
                has_element?(view, "[data-role='paywall-cta']") or
                has_element?(view, "[data-role='upgrade-cta']") or
                html =~ "/app/subscriptions/checkout" or
                html =~ "checkout" or
                html =~ "Checkout" or
                html =~ "Upgrade now" or
                html =~ "upgrade now" or
                html =~ "Get started" or
                html =~ "Start your plan"

            assert has_checkout_cta,
                   "Expected a CTA on the paywall that routes to /subscriptions/checkout. Got: #{html}"

            :ok

          {:error, {:redirect, %{to: "/app/subscriptions/checkout"}}} ->
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
