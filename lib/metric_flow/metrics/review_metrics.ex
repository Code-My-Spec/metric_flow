defmodule MetricFlow.Metrics.ReviewMetrics do
  @moduledoc """
  Computes rolling review metrics from raw review data stored in the metrics table.

  Derives three platform-agnostic computed metrics from rows where
  `metric_type = "reviews"`:

  - `review_count` — daily count of reviews received
  - `review_total_count` — running total of all reviews up to each day
  - `review_average_rating` — rolling average star rating up to each day

  All computation is done in Elixir after fetching daily aggregates from the
  database, making these metrics platform-agnostic regardless of the
  originating provider.
  """

  use Boundary

  import Ecto.Query

  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  @type daily_review_row :: %{
          date: Date.t(),
          daily_count: integer(),
          daily_rating_sum: float()
        }

  @type rolling_metric :: %{date: Date.t(), value: float()}

  # ---------------------------------------------------------------------------
  # query_rolling_review_metrics/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns computed rolling review metrics for the scoped user.

  Queries all `metric_type = "reviews"` rows from the metrics table (optionally
  filtered by date_range) and returns a map with three keys:

  - `:review_count` — list of `%{date, value}` maps with the daily count
  - `:review_total_count` — list of `%{date, value}` maps with the running total
  - `:review_average_rating` — list of `%{date, value}` maps with the rolling average rating

  All three lists are sorted by date ascending and cover only dates that have
  at least one review. Accepts the same `date_range: {start_date, end_date}`
  option as other metric queries.
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
      from(m in Metric,
        where: m.user_id == ^user_id and m.metric_type == "reviews"
      )

    base
    |> apply_date_range_filter(opts)
    |> group_by([m], fragment("?::date", m.recorded_at))
    |> order_by([m], asc: fragment("?::date", m.recorded_at))
    |> select([m], %{
      date: fragment("?::date", m.recorded_at),
      daily_count:
        fragment("COUNT(*) FILTER (WHERE ? = 'review_count')", m.metric_name),
      daily_rating_sum:
        fragment("COALESCE(SUM(?) FILTER (WHERE ? = 'review_rating'), 0.0)", m.value, m.metric_name),
      daily_rating_count:
        fragment("COUNT(*) FILTER (WHERE ? = 'review_rating')", m.metric_name)
    })
    |> Repo.all()
  end

  defp apply_date_range_filter(query, opts) do
    case Keyword.get(opts, :date_range) do
      nil ->
        query

      {start_date, end_date} ->
        start_dt = DateTime.new!(start_date, ~T[00:00:00.000000], "Etc/UTC")
        end_dt = DateTime.new!(end_date, ~T[23:59:59.999999], "Etc/UTC")
        where(query, [m], m.recorded_at >= ^start_dt and m.recorded_at <= ^end_dt)
    end
  end

  # ---------------------------------------------------------------------------
  # Private — rolling computation
  # ---------------------------------------------------------------------------

  defp compute_rolling_metrics(daily_rows) do
    {review_count, review_total_count, review_average_rating, _, _} =
      Enum.reduce(daily_rows, {[], [], [], 0, {0, 0.0}}, fn row, {counts, totals, avgs, running_count, {rating_count, rating_sum}} ->
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
      end)

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
