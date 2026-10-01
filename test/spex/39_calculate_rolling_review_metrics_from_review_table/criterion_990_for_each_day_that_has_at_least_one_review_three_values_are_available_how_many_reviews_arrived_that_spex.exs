defmodule MetricFlowSpex.EachDayWithAReviewHasDailyCountRunningTotalAndRollingAverageSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "For each day that has at least one review, three values are available: how many reviews arrived that day, the running total of all reviews to date, and the rolling average rating to date",
       criterion: 990 do
    scenario "two days with reviews each show their own daily count, running total, and rolling average" do
      given_ :user_logged_in_as_owner

      given_ "reviews arrive on two separate days", context do
        yesterday = Date.add(Date.utc_today(), -1)
        today = Date.utc_today()

        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: yesterday,
          star_rating: 4
        })

        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: today,
          star_rating: 2
        })

        {:ok, Map.merge(context, %{yesterday: yesterday, today: today})}
      end

      when_ "the user views the review metrics dashboard", context do
        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "each day shows how many reviews arrived that day, the running total to date, and the rolling average rating to date",
            context do
        yesterday_row =
          "[data-role='rolling-review-metric-row'][data-date='#{context.yesterday}']"

        today_row = "[data-role='rolling-review-metric-row'][data-date='#{context.today}']"

        assert has_element?(
                 context.view,
                 yesterday_row <> " [data-role='daily-review-count']",
                 "1"
               )

        assert has_element?(
                 context.view,
                 yesterday_row <> " [data-role='running-review-total']",
                 "1"
               )

        assert has_element?(
                 context.view,
                 yesterday_row <> " [data-role='rolling-review-average-rating']",
                 "4.0"
               )

        assert has_element?(
                 context.view,
                 today_row <> " [data-role='daily-review-count']",
                 "1"
               )

        assert has_element?(
                 context.view,
                 today_row <> " [data-role='running-review-total']",
                 "2"
               )

        assert has_element?(
                 context.view,
                 today_row <> " [data-role='rolling-review-average-rating']",
                 "3.0"
               )

        {:ok, context}
      end
    end
  end
end
