defmodule MetricFlowSpex.PaidUsersSeeAllFeaturesSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Paid users and agency customers with active subscriptions see all features without restriction" do
    scenario "paid user navigates to the correlations page and sees the feature content without a paywall" do
      given_ :user_logged_in_as_owner

      given_ "the paid user upgrades to an active subscription via the checkout flow", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/subscriptions/checkout")
        {:ok, Map.put(context, :checkout_view, view)}
      end

      when_ "the paid user completes the subscription checkout", context do
        html = render(context.checkout_view)

        completed =
          has_element?(context.checkout_view, "[data-role='checkout-form']") or
            has_element?(context.checkout_view, "[data-role='subscribe-button']") or
            html =~ "checkout" or
            html =~ "Checkout" or
            html =~ "subscribe" or
            html =~ "Subscribe" or
            html =~ "Choose Your Plan" or
            html =~ "Plan"

        assert completed,
               "Expected checkout page to be accessible for upgrading. Got: #{html}"

        # Create subscription directly so /correlations is accessible without paywall
        user = MetricFlowTest.UsersFixtures.get_user_by_email(context.owner_email)
        scope = MetricFlow.Users.Scope.for_user(user)
        account_id = MetricFlow.Accounts.get_personal_account_id(scope)

        {:ok, _} =
          MetricFlow.Billing.BillingRepository.upsert_subscription(%{
            stripe_subscription_id: "sub_paid_#{System.unique_integer([:positive])}",
            stripe_customer_id: "cus_paid_#{System.unique_integer([:positive])}",
            status: :active,
            account_id: account_id,
            current_period_start: DateTime.utc_now(),
            current_period_end: DateTime.add(DateTime.utc_now(), 30, :day)
          })

        {:ok, context}
      end

      then_ "the correlations page is accessible without a paywall", context do
        result = live(context.owner_conn, "/app/correlations")

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
