defmodule MetricFlowSpex.SummaryViewShowsActiveSubscribersAndMrrFromLocalDataSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Summary view shows active subscribers and MRR from local data", criterion: 506 do
    scenario "Acme Agency has several active customer subscriptions stored locally" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      given_ "Acme Agency has two active customer subscriptions", context do
        MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)
        MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)
        {:ok, context}
      end

      when_ "Alex opens the summary view", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alex sees the total active subscriber count and MRR computed from the local database, not a live Stripe call",
            context do
        html = render(context.view)
        assert html =~ "Active Subscribers"
        assert html =~ "2"
        assert html =~ "MRR"

        expected_dollars = context.agency_plan.price_cents * 2 / 100
        expected_formatted = "$" <> :erlang.float_to_binary(expected_dollars, decimals: 2)
        assert html =~ expected_formatted,
               "Expected MRR to be computed locally as #{expected_formatted}. Got: #{html}"

        {:ok, context}
      end
    end
  end
end
