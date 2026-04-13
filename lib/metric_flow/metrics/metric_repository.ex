defmodule MetricFlow.Metrics.MetricRepository do
  @moduledoc """
  Data access layer for Metric CRUD and query operations filtered by user_id.

  All operations are scoped via the Scope struct for multi-tenant isolation.
  Provides list_metrics/2 with filter options (provider, metric_type,
  metric_name, date_range, limit, offset), get_metric/2, create_metric/2,
  create_metrics/2 for bulk insert, delete_metrics_by_provider/2,
  query_time_series/3 for date-grouped aggregation, aggregate_metrics/3 for
  summary statistics, and list_metric_names/2 for distinct name discovery.
  """

  use Boundary

  import Ecto.Query

  alias MetricFlow.Metrics.Metric
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # list_metrics/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns all metrics for the scoped user with optional filter and pagination
  options.

  Filters by provider, metric_type, metric_name, or date_range, with
  limit/offset for pagination. Results are ordered by recorded_at descending.
  """
  @spec list_metrics(Scope.t(), keyword()) :: list(Metric.t())
  def list_metrics(%Scope{user: user}, opts \\ []) do
    from(m in Metric, where: m.user_id == ^user.id)
    |> apply_provider_filter(opts)
    |> apply_metric_type_filter(opts)
    |> apply_metric_name_filter(opts)
    |> apply_date_range_filter(opts)
    |> order_by([m], desc: m.recorded_at)
    |> apply_limit(opts)
    |> apply_offset(opts)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # get_metric/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves a single metric record by ID for the scoped user.

  Returns {:ok, metric} when found or {:error, :not_found} when the metric
  does not exist or belongs to a different user.
  """
  @spec get_metric(Scope.t(), integer()) :: {:ok, Metric.t()} | {:error, :not_found}
  def get_metric(%Scope{user: user}, id) do
    result =
      from(m in Metric, where: m.user_id == ^user.id and m.id == ^id)
      |> Repo.one()

    case result do
      nil -> {:error, :not_found}
      metric -> {:ok, metric}
    end
  end

  # ---------------------------------------------------------------------------
  # create_metric/2
  # ---------------------------------------------------------------------------

  @doc """
  Inserts a single metric record for the scoped user.

  Merges user_id from the scope into attrs before inserting. The scope's
  user_id always takes precedence over any user_id in the attrs map.
  """
  @spec create_metric(Scope.t(), map()) :: {:ok, Metric.t()} | {:error, Ecto.Changeset.t()}
  def create_metric(%Scope{user: user}, attrs) do
    attrs_with_user = Map.put(attrs, :user_id, user.id)

    %Metric{}
    |> Metric.changeset(attrs_with_user)
    |> Repo.insert()
  end

  # ---------------------------------------------------------------------------
  # create_metrics/2
  # ---------------------------------------------------------------------------

  @doc """
  Bulk-inserts a list of metric attribute maps for the scoped user in a single
  database operation.

  Returns {:ok, count} where count is the number of inserted records.
  """
  @spec create_metrics(Scope.t(), list(map())) :: {:ok, integer()} | {:error, term()}
  def create_metrics(%Scope{user: user}, attrs_list) do
    now = DateTime.utc_now() |> DateTime.truncate(:microsecond)

    entries =
      Enum.map(attrs_list, fn attrs ->
        attrs
        |> Map.put(:user_id, user.id)
        |> Map.update(:metric_name, nil, &if(is_binary(&1), do: String.downcase(&1), else: &1))
        |> Map.put(:inserted_at, now)
        |> Map.put(:updated_at, now)
      end)

    {count, _} = Repo.insert_all(Metric, entries)
    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # delete_metrics_by_provider/2
  # ---------------------------------------------------------------------------

  @doc """
  Deletes all metric records for the scoped user belonging to a specific
  provider.

  Returns {:ok, count} where count is the number of deleted records. Used when
  a provider integration is disconnected.
  """
  @spec delete_metrics_by_provider(Scope.t(), atom()) :: {:ok, integer()}
  def delete_metrics_by_provider(%Scope{user: user}, provider) do
    {count, _} =
      from(m in Metric, where: m.user_id == ^user.id and m.provider == ^provider)
      |> Repo.delete_all()

    {:ok, count}
  end

  # ---------------------------------------------------------------------------
  # query_time_series/3
  # ---------------------------------------------------------------------------

  @doc """
  Returns metric values as a time series grouped by date for a given metric
  name.

  Sums values per date and orders by date ascending. Defaults to the last 30
  days when date_range is not provided. Used by dashboards for charting and
  by correlations for analysis.
  """
  @spec query_time_series(Scope.t(), String.t(), keyword()) ::
          list(%{date: Date.t(), value: float()})
  def query_time_series(%Scope{user: user}, metric_name, opts) do
    date_range = resolve_time_series_date_range(opts)

    from(m in Metric, where: m.user_id == ^user.id)
    |> apply_metric_name_or_normalized(metric_name)
    |> apply_provider_filter(opts)
    |> apply_date_range_filter_with_default(date_range)
    |> group_by([m], fragment("?::date", m.recorded_at))
    |> order_by([m], asc: fragment("?::date", m.recorded_at))
    |> select([m], %{date: fragment("?::date", m.recorded_at), value: sum(m.value)})
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # aggregate_metrics/3
  # ---------------------------------------------------------------------------

  @doc """
  Returns aggregated statistics (sum, average, min, max, count) for a given
  metric name.

  Returns a zeroed map when no records match. Used by dashboards for summary
  stats and by AI context for insights.
  """
  @spec aggregate_metrics(Scope.t(), String.t(), keyword()) :: %{
          sum: float(),
          avg: float(),
          min: float(),
          max: float(),
          count: integer()
        }
  def aggregate_metrics(%Scope{user: user}, metric_name, opts) do
    result =
      from(m in Metric, where: m.user_id == ^user.id and m.metric_name == ^metric_name)
      |> apply_provider_filter(opts)
      |> apply_date_range_filter(opts)
      |> select([m], %{
        sum: sum(m.value),
        avg: avg(m.value),
        min: min(m.value),
        max: max(m.value),
        count: count(m.id)
      })
      |> Repo.one()

    normalize_aggregates(result)
  end

  # ---------------------------------------------------------------------------
  # list_metric_names/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns a sorted list of distinct metric names available for the scoped user.

  Used by Goals UI for metric selection and dashboard configuration.
  """
  @spec list_metric_names(Scope.t(), keyword()) :: list(String.t())
  def list_metric_names(%Scope{user: user}, opts \\ []) do
    from(m in Metric, where: m.user_id == ^user.id)
    |> apply_provider_filter(opts)
    |> distinct(true)
    |> order_by([m], asc: m.metric_name)
    |> select([m], m.metric_name)
    |> Repo.all()
  end

  @doc """
  Returns distinct normalized metric names for the scoped user, sorted alphabetically.

  These are canonical cross-provider names (e.g. "clicks", "impressions", "users")
  suitable for aggregation, display, and LLM context.
  """
  @spec list_normalized_metric_names(Scope.t(), keyword()) :: list(String.t())
  def list_normalized_metric_names(%Scope{user: user}, opts \\ []) do
    from(m in Metric,
      where: m.user_id == ^user.id,
      where: not is_nil(m.normalized_metric_name) and m.normalized_metric_name != ""
    )
    |> apply_provider_filter(opts)
    |> distinct(true)
    |> order_by([m], asc: m.normalized_metric_name)
    |> select([m], m.normalized_metric_name)
    |> Repo.all()
  end

  # ---------------------------------------------------------------------------
  # list_metric_providers/2
  # ---------------------------------------------------------------------------

  @doc """
  Returns a map of metric_name => provider for all distinct metric name/provider
  pairs for the scoped user.

  When a metric name has data from multiple providers, the first provider
  (alphabetically) is returned. Used by Dashboards to annotate summary stats
  with their originating platform.
  """
  @spec list_metric_providers(Scope.t(), keyword()) :: %{String.t() => atom()}
  def list_metric_providers(%Scope{user: user}, opts \\ []) do
    from(m in Metric, where: m.user_id == ^user.id)
    |> apply_provider_filter(opts)
    |> apply_date_range_filter(opts)
    |> group_by([m], [m.metric_name, m.provider])
    |> select([m], {m.metric_name, m.provider})
    |> Repo.all()
    |> Enum.into(%{}, fn {name, provider} -> {name, provider} end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Match on normalized_metric_name first, fall back to metric_name for backward compat
  defp apply_metric_name_or_normalized(query, name) do
    where(query, [m], m.normalized_metric_name == ^name or m.metric_name == ^name)
  end

  defp apply_provider_filter(query, opts) do
    case Keyword.get(opts, :provider) do
      nil -> query
      providers when is_list(providers) -> where(query, [m], m.provider in ^providers)
      provider -> where(query, [m], m.provider == ^provider)
    end
  end

  defp apply_metric_type_filter(query, opts) do
    case Keyword.get(opts, :metric_type) do
      nil -> query
      metric_type -> where(query, [m], m.metric_type == ^metric_type)
    end
  end

  defp apply_metric_name_filter(query, opts) do
    case Keyword.get(opts, :metric_name) do
      nil -> query
      metric_name -> where(query, [m], m.metric_name == ^metric_name)
    end
  end

  defp apply_date_range_filter(query, opts) do
    case Keyword.get(opts, :date_range) do
      nil -> query
      {start_date, end_date} -> apply_date_bounds(query, start_date, end_date)
    end
  end

  defp apply_date_range_filter_with_default(query, {start_date, end_date}) do
    apply_date_bounds(query, start_date, end_date)
  end

  defp apply_date_bounds(query, start_date, end_date) do
    start_dt = date_to_start_of_day(start_date)
    end_dt = date_to_end_of_day(end_date)

    where(query, [m], m.recorded_at >= ^start_dt and m.recorded_at <= ^end_dt)
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

  defp resolve_time_series_date_range(opts) do
    case Keyword.get(opts, :date_range) do
      nil ->
        start_date = Date.utc_today() |> Date.add(-30)
        end_date = Date.utc_today()
        {start_date, end_date}

      date_range ->
        date_range
    end
  end

  defp date_to_start_of_day(%Date{} = date) do
    DateTime.new!(date, ~T[00:00:00.000000], "Etc/UTC")
  end

  defp date_to_end_of_day(%Date{} = date) do
    DateTime.new!(date, ~T[23:59:59.999999], "Etc/UTC")
  end

  defp normalize_aggregates(%{count: 0}), do: %{sum: 0.0, avg: 0.0, min: 0.0, max: 0.0, count: 0}

  defp normalize_aggregates(%{sum: sum, avg: avg, min: min, max: max, count: count}) do
    %{
      sum: decimal_to_float(sum),
      avg: decimal_to_float(avg),
      min: decimal_to_float(min),
      max: decimal_to_float(max),
      count: count
    }
  end

  defp decimal_to_float(%Decimal{} = d), do: Decimal.to_float(d)
  defp decimal_to_float(v) when is_float(v), do: v
  defp decimal_to_float(v) when is_integer(v), do: v * 1.0
  defp decimal_to_float(nil), do: 0.0
end
