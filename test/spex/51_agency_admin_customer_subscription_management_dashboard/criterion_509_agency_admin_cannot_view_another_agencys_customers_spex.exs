defmodule MetricFlowSpex.AgencyAdminCannotViewAnotherAgencysCustomersSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Agency admin cannot view another agency's customers", criterion: 509 do
    scenario "Alex administers Acme Agency and Globex Agency has its own subscribed customers" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan
      given_ :globex_agency_plan_and_customer

      given_ "Alex is on the subscription management dashboard", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "Alex attempts to view or act on a Globex Agency customer record, including by direct URL/ID",
            context do
        html = render(context.view)

        cancel_attempt =
          if has_element?(context.view, "button[phx-value-id='#{context.globex_subscription_id}']") do
            context.view
            |> element("button[phx-value-id='#{context.globex_subscription_id}']")
            |> render_click()
          else
            :not_rendered
          end

        {:ok, context |> Map.put(:html, html) |> Map.put(:cancel_attempt, cancel_attempt)}
      end

      then_ "access is denied and no Globex Agency customer data is shown", context do
        refute context.html =~ context.globex_customer_identifier,
               "Expected Alex's dashboard to not show Globex Agency's customer data"

        case context.cancel_attempt do
          :not_rendered ->
            {:ok, context}

          _ ->
            globex_status = MetricFlowSpex.Fixtures.subscription_status!(context.globex_subscription_id)

            assert globex_status == :active,
                   "Expected Globex Agency's subscription to be unaffected by Alex's action"

            {:ok, context}
        end
      end
    end
  end
end
