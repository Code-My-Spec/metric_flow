defmodule MetricFlow.Reviews.ReviewMetrics do
  @moduledoc """
  Computes rolling review metrics from the reviews table.

  Provides query_rolling_review_metrics/2 which returns daily review count,
  running total count, and rolling average star rating as date-keyed time
  series. Platform-agnostic — aggregates across all providers. Used by
  provider dashboards and the correlation engine.
  """

  use Boundary

  import Ecto.Query

  alias MetricFlow.Reviews.Review
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @type daily_review_row :: %{
          date: Date.t(),
          daily_count: integer(),
          daily_rating_sum: float()
        }

  @type rolling_metric :: %{date: Date.t(), value: float()}

  @doc """
  Returns computed rolling review metrics for the scoped user, derived from the reviews table.

  Queries all rows from the `reviews` table belonging to the user (optionally filtered
  by date range) and returns a map with three keys: `:review_count`, `:review_total_count`,
  and `:review_average_rating`. Each key maps to a list of `%{date, value}` maps sorted
  by date ascending, covering only dates that have at least one review.
  Aggregates across all providers.
  """
  @spec query_rolling_review_metrics(Scope.t(), keyword()) :: %{
          review_count: list(rolling_metric()),
          review_total_count: list(rolling_metric()),
          review_average_rating: list(rolling_metric())
        }
  def query_rolling_review_metrics(%Scope{user: user}, opts \\ []) do
    daily_rows = fetch_daily_review_aggregates(user.id, opts)
    compute_rolling_metrics(daily_rows)
  end

  # ---------------------------------------------------------------------------
  # Private — data fetching
  # ---------------------------------------------------------------------------

  defp fetch_daily_review_aggregates(user_id, opts) do
    base =
      from(r in Review,
        where: r.user_id == ^user_id
      )

    base
    |> apply_date_range_filter(opts)
    |> group_by([r], r.review_date)
    |> order_by([r], asc: r.review_date)
    |> select([r], %{
      date: r.review_date,
      daily_count: count(r.id),
      daily_rating_sum: coalesce(sum(r.star_rating), 0),
      daily_rating_count: fragment("COUNT(?) FILTER (WHERE ? IS NOT NULL)", r.star_rating, r.star_rating)
    })
    |> Repo.all()
  end

  defp apply_date_range_filter(query, opts) do
    case Keyword.get(opts, :date_range) do
      nil ->
        query

      {start_date, end_date} ->
        where(query, [r], r.review_date >= ^start_date and r.review_date <= ^end_date)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — rolling computation
  # ---------------------------------------------------------------------------

  defp compute_rolling_metrics(daily_rows) do
    {review_count, review_total_count, review_average_rating, _, _} =
      Enum.reduce(
        daily_rows,
        {[], [], [], 0, {0, 0.0}},
        fn row, {counts, totals, avgs, running_count, {rating_count, rating_sum}} ->
          day_count = to_integer(row.daily_count)
          day_rating_count = to_integer(row.daily_rating_count)
          day_rating_sum = to_float(row.daily_rating_sum)

          new_running_count = running_count + day_count
          new_rating_count = rating_count + day_rating_count
          new_rating_sum = rating_sum + day_rating_sum

          rolling_avg =
            if new_rating_count > 0,
              do: new_rating_sum / new_rating_count,
              else: 0.0

          date = row.date

          new_counts = [%{date: date, value: day_count * 1.0} | counts]
          new_totals = [%{date: date, value: new_running_count * 1.0} | totals]
          new_avgs = [%{date: date, value: rolling_avg} | avgs]

          {new_counts, new_totals, new_avgs, new_running_count, {new_rating_count, new_rating_sum}}
        end
      )

    %{
      review_count: Enum.reverse(review_count),
      review_total_count: Enum.reverse(review_total_count),
      review_average_rating: Enum.reverse(review_average_rating)
    }
  end

  defp to_integer(val) when is_integer(val), do: val
  defp to_integer(%Decimal{} = d), do: Decimal.to_integer(d)
  defp to_integer(val) when is_float(val), do: trunc(val)
  defp to_integer(nil), do: 0

  defp to_float(val) when is_float(val), do: val
  defp to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp to_float(val) when is_integer(val), do: val * 1.0
  defp to_float(nil), do: 0.0
end
