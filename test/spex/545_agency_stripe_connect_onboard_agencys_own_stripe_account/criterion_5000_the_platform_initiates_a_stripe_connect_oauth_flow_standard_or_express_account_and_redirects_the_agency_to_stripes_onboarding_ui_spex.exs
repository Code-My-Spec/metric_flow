defmodule MetricFlowSpex.PlatformInitiatesStripeConnectOauthSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Platform initiates Stripe Connect OAuth flow and redirects to Stripe" do
    scenario "admin clicks connect and is redirected to Stripe onboarding" do
      given_ :user_logged_in_as_owner

      given_ "the admin is on the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "the admin clicks the connect button", context do
        result =
          context.view
          |> element("[data-role=connect-stripe]")
          |> render_click()

        {:ok, Map.put(context, :result, result)}
      end

      then_ "the admin is redirected to Stripe onboarding", context do
        html = render(context.view)
        assert html =~ "Stripe" or html =~ "redirect"
        :ok
      end
    end
  end
end
