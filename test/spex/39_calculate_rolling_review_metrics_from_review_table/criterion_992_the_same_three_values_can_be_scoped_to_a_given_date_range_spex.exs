defmodule MetricFlowSpex.RollingReviewMetricsCanBeScopedToADateRangeSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "The same three values can be scoped to a given date range", criterion: 992 do
    scenario "narrowing the date range excludes a review recorded well outside of it" do
      given_ :user_logged_in_as_owner

      given_ "the account has one review from 90 days ago and one review from yesterday",
             context do
        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: Date.add(Date.utc_today(), -90),
          star_rating: 1
        })

        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: Date.add(Date.utc_today(), -1),
          star_rating: 5
        })

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.put(context, :view, view)}
      end

      when_ "the user narrows the date range to the last 7 days", context do
        context.view
        |> form("form[phx-change='change_date_range']", date_range: "last_7_days")
        |> render_change()

        {:ok, context}
      end

      then_ "the daily count, running total, and rolling average are scoped to that range, excluding the review from outside it",
            context do
        assert has_element?(context.view, "[data-role='running-review-total']", "1")
        refute has_element?(context.view, "[data-role='running-review-total']", "2")
        {:ok, context}
      end
    end
  end
end
