defmodule MetricFlowTest.ReviewsFixtures do
  @moduledoc """
  Test helpers for creating review entities via the Reviews context.
  """

  alias MetricFlow.Reviews

  @doc """
  Creates and persists a Review record for the given scope.
  Accepts optional attribute overrides.
  """
  def review_fixture(scope, attrs \\ %{}) do
    unique = System.unique_integer([:positive])

    defaults = %{
      provider: :google_business,
      external_review_id: "review-#{unique}",
      reviewer_name: "Reviewer #{unique}",
      star_rating: 5,
      comment: "Great service!",
      review_date: Date.utc_today(),
      provider_metadata: %{}
    }

    merged = Map.merge(defaults, Map.new(attrs))

    {:ok, [review]} = Reviews.create_reviews(scope, [merged])
    review
  end
end
