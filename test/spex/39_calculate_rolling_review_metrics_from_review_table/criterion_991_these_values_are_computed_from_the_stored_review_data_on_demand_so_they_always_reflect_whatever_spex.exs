defmodule MetricFlowSpex.RollingReviewMetricsAreComputedOnDemandNotPreCalculatedSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "These values are computed from the stored review data on demand, so they always reflect whatever reviews have been synced most recently, rather than being pre-calculated and stored separately",
       criterion: 991 do
    scenario "a review synced after the dashboard was first viewed is reflected immediately on the next view, with no separate recalculation step" do
      given_ :user_logged_in_as_owner

      given_ "the account has one review, and the dashboard has already been viewed once", context do
        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: Date.utc_today(),
          star_rating: 5
        })

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        assert has_element?(view, "[data-role='running-review-total']", "1")

        {:ok, context}
      end

      when_ "a new review is synced and the dashboard is viewed again", context do
        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: Date.utc_today(),
          star_rating: 3
        })

        {:ok, view, _html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.put(context, :view, view)}
      end

      then_ "the newly-synced review is already reflected, proving the values were recomputed on demand rather than read from a stale cache",
            context do
        assert has_element?(context.view, "[data-role='running-review-total']", "2")
        {:ok, context}
      end
    end
  end
end
