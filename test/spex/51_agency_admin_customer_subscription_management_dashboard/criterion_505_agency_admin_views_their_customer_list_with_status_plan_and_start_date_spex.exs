defmodule MetricFlowSpex.AgencyAdminViewsTheirCustomerListWithStatusPlanAndStartDateSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency admin views their customer list with status, plan, and start date", criterion: 505 do
    scenario "Alex administers Acme Agency with subscribed customers" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      given_ "Acme Agency has a subscribed customer", context do
        subscription =
          MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)

        {:ok, Map.put(context, :customer_subscription, subscription)}
      end

      when_ "Alex opens the subscription management dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "Alex sees each customer's subscription status, plan, and subscription start date", context do
        html = render(context.view)
        assert html =~ context.customer_subscription.stripe_customer_id
        assert html =~ context.agency_plan.name
        assert html =~ "Active"
        assert html =~ "Start Date"
        {:ok, context}
      end
    end
  end
end
