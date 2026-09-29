defmodule MetricFlowSpex.CustomerListPaginatesWhenThereAreMoreCustomersThanFitOnePageSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Customer list paginates when there are more customers than fit one page", criterion: 510 do
    scenario "Acme Agency has more subscribed customers than fit on one page" do
      given_ :user_logged_in_as_owner
      given_ :owner_has_agency_plan

      given_ "Acme Agency has more subscribed customers than fit on one page", context do
        for _ <- 1..21 do
          MetricFlowSpex.Fixtures.agency_customer_subscription!(context.owner_email, context.agency_plan)
        end

        {:ok, context}
      end

      when_ "Alex opens the customer list", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/agency/subscriptions")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the list is paginated and Alex can navigate between pages", context do
        assert has_element?(context.view, "button", "Next"),
               "Expected a way to move to the next page when there are more customers than fit on one page"

        context.view |> element("button", "Next") |> render_click()

        assert has_element?(context.view, "button", "Previous"),
               "Expected a way to navigate back after moving to the next page"

        {:ok, context}
      end
    end
  end
end
