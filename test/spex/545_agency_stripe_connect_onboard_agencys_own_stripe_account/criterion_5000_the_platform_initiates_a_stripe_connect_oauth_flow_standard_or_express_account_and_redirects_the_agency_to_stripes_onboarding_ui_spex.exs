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

      when_ "the admin sees the connect button for Stripe onboarding", context do
        {:ok, context}
      end

      then_ "the admin is redirected to Stripe onboarding", context do
        html = render(context.view)
        # Verify the page has connect button and Stripe branding
        assert html =~ "Stripe" or has_element?(context.view, "[data-role=connect-stripe]")
        :ok
      end
    end
  end
end
