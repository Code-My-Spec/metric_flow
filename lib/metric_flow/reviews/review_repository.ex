defmodule MetricFlow.Reviews.ReviewRepository do
  @moduledoc """
  Data access layer for Review CRUD and query operations.

  All queries are scoped via the Scope struct for multi-tenant isolation.
  Provides create_reviews/2 for bulk upsert (deduplicates on external_review_id),
  list_reviews/2 with filter options (provider, location_id, date_range, limit, offset),
  and delete_reviews_by_provider/2.
  """

  use Boundary

  import Ecto.Query

  alias MetricFlow.Reviews.Review
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # create_reviews/2
  # ---------------------------------------------------------------------------

  @doc """
  Bulk-inserts or updates a list of review attribute maps for the scoped user.

  Deduplicates on external_review_id — if a review with the same
  external_review_id already exists, all fields except id and inserted_at are
  updated. Returns {:ok, count} where count is the number of rows affected.
  """
  @spec create_reviews(Scope.t(), list(map())) :: {:ok, integer()}
  def create_reviews(%Scope{user: user}, attrs_list) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    entries =
      Enum.map(attrs_list, fn attrs ->
        provider = normalize_provider(Map.get(attrs, :provider) || Map.get(attrs, "provider"))

        %{
          user_id: user.id,
          integration_id: Map.get(attrs, :integration_id) || Map.get(attrs, "integration_id"),
          provider: provider,
          external_review_id: Map.get(attrs, :external_review_id) || Map.get(attrs, "external_review_id"),
          reviewer_name: Map.get(attrs, :reviewer_name) || Map.get(attrs, "reviewer_name"),
          star_rating: Map.get(attrs, :star_rating) || Map.get(attrs, "star_rating"),
          comment: Map.get(attrs, :comment) || Map.get(attrs, "comment"),
          review_date: Map.get(attrs, :review_date) || Map.get(attrs, "review_date"),
          location_id: Map.get(attrs, :location_id) || Map.get(attrs, "location_id"),
          metadata: Map.get(attrs, :metadata) || Map.get(attrs, "metadata") || %{},
          inserted_at: now,
          updated_at: now
        }
      end)

    {count, _} =
      Repo.insert_all(
        Review,
        entries,
        on_conflict: {:replace_all_except, [:id, :inserted_at]},
        conflict_target: [:external_review_id]
      )

    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # list_reviews/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns a list of reviews for the scoped user with optional filter options.

  Supported options:
  - `provider` — filter by provider atom or list of provider atoms
  - `location_id` — filter by location_id string
  - `date_range: {start_date, end_date}` — filter by review_date range
  - `limit` — limit the number of returned rows
  - `offset` — skip a number of rows

  Results are ordered by review_date descending.
  """
  @spec list_reviews(Scope.t(), keyword()) :: list(Review.t())
  def list_reviews(%Scope{user: user}, opts \\ []) do
    from(r in Review, where: r.user_id == ^user.id)
    |> apply_provider_filter(opts)
    |> apply_location_filter(opts)
    |> apply_date_range_filter(opts)
    |> order_by([r], desc: r.review_date, desc: r.id)
    |> apply_limit(opts)
    |> apply_offset(opts)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # get_review/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns a single review by id for the scoped user.

  Returns {:ok, review} if found, {:error, :not_found} if the review does not
  exist or does not belong to the scoped user.
  """
  @spec get_review(Scope.t(), integer()) :: {:ok, Review.t()} | {:error, :not_found}
  def get_review(%Scope{user: user}, id) do
    case Repo.get_by(Review, id: id, user_id: user.id) do
      nil -> {:error, :not_found}
      review -> {:ok, review}
    end
  end

  # ---------------------------------------------------------------------------
  # delete_reviews_by_provider/2
  # ---------------------------------------------------------------------------

  @doc """
  Deletes all review records for the scoped user belonging to a specific provider.

  Returns {:ok, count} where count is the number of deleted records. Used when
  a provider integration is disconnected.
  """
  @spec delete_reviews_by_provider(Scope.t(), atom()) :: {:ok, integer()}
  def delete_reviews_by_provider(%Scope{user: user}, provider) do
    {count, _} =
      from(r in Review, where: r.user_id == ^user.id and r.provider == ^provider)
      |> Repo.delete_all()

    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp apply_provider_filter(query, opts) do
    case Keyword.get(opts, :provider) do
      nil -> query
      providers when is_list(providers) -> where(query, [r], r.provider in ^providers)
      provider -> where(query, [r], r.provider == ^provider)
    end
  end

  defp apply_location_filter(query, opts) do
    case Keyword.get(opts, :location_id) do
      nil -> query
      location_id -> where(query, [r], r.location_id == ^location_id)
    end
  end

  defp apply_date_range_filter(query, opts) do
    case Keyword.get(opts, :date_range) do
      nil -> query
      {start_date, end_date} -> where(query, [r], r.review_date >= ^start_date and r.review_date <= ^end_date)
    end
  end

  defp apply_limit(query, opts) do
    case Keyword.get(opts, :limit) do
      nil -> query
      limit -> limit(query, ^limit)
    end
  end

  defp apply_offset(query, opts) do
    case Keyword.get(opts, :offset) do
      nil -> query
      offset -> offset(query, ^offset)
    end
  end

  defp normalize_provider(provider) when is_atom(provider), do: provider
  defp normalize_provider(provider) when is_binary(provider), do: String.to_existing_atom(provider)
  defp normalize_provider(nil), do: nil
end
