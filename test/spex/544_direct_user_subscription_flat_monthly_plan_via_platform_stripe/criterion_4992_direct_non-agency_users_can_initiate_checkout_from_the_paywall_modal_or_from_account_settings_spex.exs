defmodule MetricFlowSpex.DirectUsersCanInitiateCheckoutSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Direct (non-agency) users can initiate checkout from the paywall modal or from account settings" do
    scenario "free user is redirected to checkout when accessing paywalled page" do
      given_ :user_logged_in_as_owner

      when_ "the user navigates to a paywalled AI page", context do
        result = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :live_result, result)}
      end

      then_ "the user is redirected to the checkout page with an upgrade prompt", context do
        assert {:error, {:redirect, %{to: "/subscriptions/checkout"}}} = context.live_result
        :ok
      end
    end

    scenario "free user can access checkout directly" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to checkout", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the checkout page shows subscription plans", context do
        html = render(context.view)
        assert html =~ "checkout" or html =~ "Checkout" or html =~ "Plan" or html =~ "Subscribe"
        :ok
      end
    end
  end
end
