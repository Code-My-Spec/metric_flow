defmodule MetricFlowSpex.RollingReviewMetricsComputedFromEveryReviewRegardlessOfPlatformSpex do
  @moduledoc """
  The Review schema currently only accepts a single provider value
  (:google_business) -- there is no second platform to prove "regardless
  of which platform" against yet. This scenario instead proves the
  narrower, currently-testable half of the claim: the rolling computation
  sums every review recorded for the account, not a subset scoped to one
  location or sync run, which is the only axis of variation the schema
  offers today and is consistent with the query never filtering by
  provider.
  """

  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "Rolling review metrics are computed from every review recorded for the account, regardless of which platform the review came from",
       criterion: 989 do
    scenario "reviews recorded under different locations are all included in the rolling totals" do
      given_ :user_logged_in_as_owner

      given_ "the account has multiple reviews recorded for its connected review platform",
             context do
        today = Date.utc_today()

        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: today,
          location_id: "location-a"
        })

        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: today,
          location_id: "location-b"
        })

        MetricFlowSpex.Fixtures.create_review_for(context.owner_email, %{
          review_date: today,
          location_id: "location-c"
        })

        {:ok, context}
      end

      when_ "the user views the review metrics dashboard", context do
        {:ok, view, html} =
          live(context.owner_conn, "/app/integrations/google_business/dashboard")

        {:ok, Map.merge(context, %{view: view, html: html})}
      end

      then_ "the rolling totals reflect every review recorded for the account, not a subset",
            context do
        assert has_element?(context.view, "[data-role='rolling-review-metrics-section']")
        assert has_element?(context.view, "[data-role='running-review-total']", "3")
        {:ok, context}
      end
    end
  end
end
