defmodule MetricFlow.Reviews do
  @moduledoc """
  Platform-agnostic review storage, retrieval, and rolling metric aggregation.

  Reviews are synced from external platforms (Google Business Profile, and future
  sources like Yelp, Trustpilot) into a dedicated `reviews` table with full review
  data. The context computes rolling review metrics (daily count, running total,
  rolling average rating) from this table.

  All public functions accept a `%Scope{}` as the first parameter for multi-tenant
  isolation.
  """

  use Boundary, deps: [MetricFlow], exports: [Review]

  import Ecto.Query

  alias MetricFlow.Repo
  alias MetricFlow.Reviews.Review
  alias MetricFlow.Reviews.ReviewMetrics
  alias MetricFlow.Reviews.ReviewRepository
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate list_reviews(scope, opts \\ []), to: ReviewRepository
  defdelegate get_review(scope, id), to: ReviewRepository
  defdelegate create_reviews(scope, attrs_list), to: ReviewRepository
  defdelegate delete_reviews_by_provider(scope, provider), to: ReviewRepository

  # ---------------------------------------------------------------------------
  # query_rolling_review_metrics/2
  # ---------------------------------------------------------------------------

  @doc """
  Computes rolling review metrics from the reviews table.

  Returns daily review count, running total count, and rolling average star rating
  as date-keyed time series.

  Accepts optional keyword options:
  - `:date_range` — `{start_date, end_date}` tuple to filter by review_date
  - `:provider` — atom to filter by a specific provider
  """
  @spec query_rolling_review_metrics(Scope.t(), keyword()) :: %{
          review_count: list(%{date: Date.t(), value: float()}),
          review_total_count: list(%{date: Date.t(), value: float()}),
          review_average_rating: list(%{date: Date.t(), value: float()})
        }
  def query_rolling_review_metrics(%Scope{} = scope, opts \\ []) do
    ReviewMetrics.query_rolling_review_metrics(scope, opts)
  end

  # ---------------------------------------------------------------------------
  # review_count/1
  # ---------------------------------------------------------------------------

  @doc """
  Returns the total number of reviews for the scoped user across all providers.
  """
  @spec review_count(Scope.t()) :: non_neg_integer()
  def review_count(%Scope{user: user}) do
    Repo.aggregate(from(r in Review, where: r.user_id == ^user.id), :count)
  end

  # ---------------------------------------------------------------------------
  # recent_reviews/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns the most recent reviews for the scoped user, ordered by review_date descending.

  Accepts optional keyword options:
  - `:limit` — maximum number of reviews to return (default: 10)
  - `:provider` — atom to filter by a specific provider
  """
  @spec recent_reviews(Scope.t(), keyword()) :: list(Review.t())
  def recent_reviews(%Scope{} = scope, opts \\ []) do
    opts_with_default_limit = Keyword.put_new(opts, :limit, 10)
    ReviewRepository.list_reviews(scope, opts_with_default_limit)
  end
end
