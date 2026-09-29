defmodule MetricFlowSpex.AgencyAdminSearchesTheCustomerListByNameOrEmailSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency admin searches the customer list by name or email", criterion: 511 do
    scenario "Acme Agency has multiple subscribed customers" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      given_ "Acme Agency has two customers with distinct identities", context do
        first = MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)
        second = MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)

        {:ok,
         context
         |> Map.put(:matching_customer_name, MetricFlowSpex.Fixtures.agency_customer_account_name!(first))
         |> Map.put(:matching_customer_id, first.stripe_customer_id)
         |> Map.put(:other_customer_id, second.stripe_customer_id)}
      end

      when_ "Alex searches the customer list by a customer's name or email", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")

        view
        |> form("form", %{"query" => context.matching_customer_name})
        |> render_change()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "only matching customers are shown", context do
        html = render(context.view)

        assert html =~ context.matching_customer_id,
               "Expected searching by the customer's name to find their row. Got: #{html}"

        refute html =~ context.other_customer_id,
               "Expected the non-matching customer to be filtered out. Got: #{html}"

        {:ok, context}
      end
    end
  end
end
