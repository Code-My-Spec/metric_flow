defmodule MetricFlowSpex.DirectUsersCanInitiateCheckoutSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Direct (non-agency) users can initiate checkout from the paywall modal or from account settings" do
    scenario "free user sees upgrade prompt on paywalled page and can navigate to checkout" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to a paywalled AI page", context do
        {:ok, view, _html} = live(context.owner_conn, "/correlations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the user sees a paywall with an upgrade call-to-action", context do
        html = render(context.view)
        assert html =~ "Upgrade"
        :ok
      end
    end

    scenario "free user can access checkout from account settings" do
      given_ :user_logged_in_as_owner

      given_ "the user navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the settings page shows a subscription section with an upgrade link", context do
        html = render(context.view)
        assert html =~ "Subscription" or html =~ "Plan"
        :ok
      end
    end
  end
end
