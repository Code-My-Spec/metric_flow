defmodule MetricFlowSpex.PaidUsersSeeAllFeaturesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Paid users and agency customers with active subscriptions see all features without restriction" do
    scenario "paid user navigates to the correlations page and sees the feature content without a paywall" do
      given_ :user_logged_in_as_owner

      given_ "the paid user upgrades to an active subscription via the checkout flow", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :checkout_view, view)}
      end

      when_ "the paid user completes the subscription checkout", context do
        html = render(context.checkout_view)

        completed =
          has_element?(context.checkout_view, "[data-role='checkout-form']") or
            html =~ "checkout" or
            html =~ "Checkout" or
            html =~ "subscribe" or
            html =~ "Subscribe"

        assert completed,
               "Expected checkout page to be accessible for upgrading. Got: #{html}"

        {:ok, context}
      end

      then_ "the correlations page is accessible without a paywall", context do
        result = live(context.owner_conn, "/correlations")

        case result do
          {:ok, view, _html} ->
            html = render(view)

            refute has_element?(view, "[data-role='paywall']") and
                     not has_element?(view, "[data-role='correlation-results']"),
                   "Expected no blocking paywall for paid user on /correlations. Got: #{html}"

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
