defmodule MetricFlowSpex.AgencyCustomerKeepsAiAccessWhileFlaggedButSubscribedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency customer keeps AI access while their subscription is flagged but still subscribed",
       criterion: 500 do
    scenario "Jordan's subscription is flagged because Acme Agency's Stripe account disconnected" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :owner_has_stripe_connect
      given_ :second_user_registered
      given_ :second_user_has_agency_plan_subscription

      given_ "the admin is on the Stripe Connect page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/stripe-connect")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Acme Agency's Stripe account disconnects, flagging Jordan's subscription for review",
            context do
        context.view |> element("[data-role=disconnect-stripe]") |> render_click()
        {:ok, context}
      end

      then_ "Jordan navigates to Visualizations and sees the full feature content with no paywall",
            context do
        result = live(context.second_user_conn, "/app/visualizations")

        case result do
          {:ok, view, _html} ->
            html = render(view)

            refute has_element?(view, "[data-role='paywall']") or
                     has_element?(view, "[data-role='upgrade-modal']"),
                   "Expected Jordan to keep AI access while flagged-but-subscribed. Got: #{html}"

            {:ok, context}

          {:error, {:redirect, %{to: path}}} ->
            flunk("Expected Jordan to keep access to /visualizations but was redirected to #{path}")

          {:error, {:live_redirect, %{to: path}}} ->
            flunk("Expected Jordan to keep access to /visualizations but was live-redirected to #{path}")
        end
      end
    end
  end
end
