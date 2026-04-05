defmodule MetricFlowSpex.OnSuccessfulPaymentAccountUpdatedSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "On successful payment, the user's account is updated to subscribed" do
    scenario "user returns from Stripe checkout success URL and sees active subscription" do
      given_ :user_logged_in_as_owner

      when_ "the user visits the checkout success callback URL", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/subscriptions/checkout/success?session_id=test_session")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the page confirms the subscription is active", context do
        html = render(context.view)
        assert html =~ "active" or html =~ "Active" or html =~ "Subscription confirmed"
        :ok
      end
    end
  end
end
