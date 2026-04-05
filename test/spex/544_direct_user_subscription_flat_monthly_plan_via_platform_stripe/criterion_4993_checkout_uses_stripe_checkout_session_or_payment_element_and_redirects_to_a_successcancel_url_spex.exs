defmodule MetricFlowSpex.CheckoutUsesStripeCheckoutSessionSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Checkout uses Stripe Checkout Session and redirects to a success/cancel URL" do
    scenario "user clicks subscribe and is redirected to Stripe checkout" do
      given_ :user_logged_in_as_owner

      given_ "the user is on the checkout page", context do
        {:ok, view, _html} = live(context.owner_conn, "/subscriptions/checkout")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user clicks the subscribe button", context do
        result =
          context.view
          |> element("[data-role=subscribe-button]")
          |> render_click()

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the user is redirected to Stripe checkout", context do
        assert {:error, {:redirect, %{to: url}}} = context.result
        assert url =~ "stripe" or url =~ "checkout"
        :ok
      end
    end
  end
end
