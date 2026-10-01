defmodule MetricFlow.Reviews do
  @moduledoc """
  Platform-agnostic review storage and retrieval.

  Reviews are synced from external platforms (Google Business Profile, and future
  sources like Yelp, Trustpilot) into a dedicated `reviews` table with full review
  data.

  All public functions accept a `%Scope{}` as the first parameter for multi-tenant
  isolation.
  """

  use Boundary, deps: [MetricFlow], exports: [Review]

  import Ecto.Query

  alias MetricFlow.Repo
  alias MetricFlow.Reviews.Review
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
