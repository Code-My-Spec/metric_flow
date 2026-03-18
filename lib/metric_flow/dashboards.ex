defmodule MetricFlow.Dashboards do
  @moduledoc """
  Public API boundary for the Dashboards bounded context.

  Aggregates and shapes metric data from the Metrics context into chart-ready
  structures for the "All Metrics" dashboard view. Delegates data retrieval to
  MetricFlow.Metrics and integration checks to MetricFlow.Integrations.

  All public functions that require user isolation accept a `%Scope{}` as the
  first parameter. Pure functions (default_date_range/0, available_date_ranges/0)
  require no scope.
  """

  use Boundary,
    deps: [MetricFlow, MetricFlow.Integrations, MetricFlow.Metrics],
    exports: [Dashboard]

  alias MetricFlow.Dashboards.ChartBuilder
  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Dashboards.DashboardsRepository
  alias MetricFlow.Integrations
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated repository functions
  # ---------------------------------------------------------------------------

  defdelegate get_dashboard(scope, id), to: DashboardsRepository

  @doc "Creates a new dashboard for the scoped user."
  @spec save_dashboard(Scope.t(), map()) :: {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  def save_dashboard(%Scope{} = scope, attrs) do
    DashboardsRepository.create_dashboard(scope, attrs)
  end

  @doc "Updates an existing dashboard with the given attributes."
  @spec update_dashboard(Scope.t(), Dashboard.t(), map()) ::
          {:ok, Dashboard.t()} | {:error, Ecto.Changeset.t()}
  def update_dashboard(%Scope{}, %Dashboard{} = dashboard, attrs) do
    DashboardsRepository.update_dashboard(dashboard, attrs)
  end

  @doc "Returns an Ecto changeset for a Dashboard."
  @spec dashboard_changeset(Dashboard.t(), map()) :: Ecto.Changeset.t()
  def dashboard_changeset(%Dashboard{} = dashboard, attrs) do
    Dashboard.changeset(dashboard, attrs)
  end

  @doc "Returns the list of available metric names for the scoped user."
  @spec list_available_metrics(Scope.t()) :: [String.t()]
  def list_available_metrics(%Scope{} = scope) do
    Metrics.list_metric_names(scope)
  end

  # ---------------------------------------------------------------------------
  # get_dashboard_data/2
  # ---------------------------------------------------------------------------

  @doc """
  Retrieves all data needed for the "All Metrics" dashboard view for the
  scoped user.

  Calls Metrics for time series and summary stats, and Integrations for
  connected platforms. Returns a unified map the LiveView can render directly.

  Supported options:
  - `:platform` — filter metrics by provider atom (maps to `:provider` in Metrics)
  - `:date_range` — `{start_date, end_date}` tuple; defaults to default_date_range/0
  - `:metric_type` — filter metrics by type string
  """
  @spec get_dashboard_data(Scope.t(), keyword()) ::
          {:ok,
           %{
             time_series:
               list(%{metric_name: String.t(), data: list(%{date: Date.t(), value: float()})}),
             summary_stats:
               list(%{
                 metric_name: String.t(),
                 stats: %{
                   sum: float(),
                   avg: float(),
                   min: float(),
                   max: float(),
                   count: integer()
                 }
               }),
             available_filters: %{
               platforms: list(atom()),
               metric_types: list(String.t()),
               metric_names: list(String.t())
             },
             connected_platforms: list(atom()),
             applied_filters: keyword()
           }}
          | {:error, term()}
  def get_dashboard_data(%Scope{} = scope, opts) do
    date_range = Keyword.get(opts, :date_range, default_date_range())
    platform = Keyword.get(opts, :platform)
    metric_type = Keyword.get(opts, :metric_type)

    applied_filters = Keyword.put_new(opts, :date_range, date_range)

    integrations = Integrations.list_integrations(scope)
    connected_platforms = Enum.map(integrations, & &1.provider)

    # Normalize compound providers (e.g. :google → [:google_analytics, :google_ads])
    # so the Metrics query uses valid provider enum values.
    metric_provider = normalize_metric_provider(platform)

    metric_query_opts =
      []
      |> maybe_put(:provider, metric_provider)
      |> maybe_put(:date_range, date_range)
      |> maybe_put(:metric_type, metric_type)

    metric_names = resolve_metric_names(scope, metric_provider, metric_type)
    all_metric_names = Metrics.list_metric_names(scope)

    time_series = build_time_series(scope, metric_names, metric_query_opts)
    summary_stats = build_summary_stats(scope, metric_names, metric_query_opts)

    available_filters = %{
      platforms: connected_platforms,
      metric_types: [],
      metric_names: all_metric_names
    }

    {:ok,
     %{
       time_series: time_series,
       summary_stats: summary_stats,
       available_filters: available_filters,
       connected_platforms: connected_platforms,
       applied_filters: applied_filters
     }}
  end

  # ---------------------------------------------------------------------------
  # build_chart_spec/2
  # ---------------------------------------------------------------------------

  @doc """
  Builds a Vega-Lite JSON specification for a time series line chart for a
  single metric.

  The returned map can be JSON-encoded and passed to vega-embed on the client
  for rendering. Delegates to MetricFlow.Dashboards.ChartBuilder.
  """
  @spec build_chart_spec(String.t(), list(%{date: Date.t(), value: float()})) :: map()
  defdelegate build_chart_spec(metric_name, data), to: ChartBuilder, as: :build_time_series_spec

  # ---------------------------------------------------------------------------
  # default_date_range/0
  # ---------------------------------------------------------------------------

  @doc """
  Returns the default date range tuple used when no date range filter is
  specified.

  End date is yesterday (to exclude the incomplete current day) and start date
  is 30 days prior.
  """
  @spec default_date_range() :: {Date.t(), Date.t()}
  def default_date_range do
    end_date = Date.utc_today() |> Date.add(-1)
    start_date = end_date |> Date.add(-30)
    {start_date, end_date}
  end

  # ---------------------------------------------------------------------------
  # available_date_ranges/0
  # ---------------------------------------------------------------------------

  @doc """
  Returns the list of preset date range options available in the filter UI.

  Each option includes an atom key, a human-readable label, and a range tuple
  `{start_date, end_date}` computed at call time so ranges stay accurate
  regardless of when they are evaluated. The `:all_time` and `:custom` entries
  have a `nil` range.
  """
  @spec available_date_ranges() ::
          list(%{key: atom(), label: String.t(), range: {Date.t(), Date.t()} | nil})
  def available_date_ranges do
    yesterday = Date.utc_today() |> Date.add(-1)

    [
      %{
        key: :last_7_days,
        label: "Last 7 Days",
        range: {Date.add(yesterday, -6), yesterday}
      },
      %{
        key: :last_30_days,
        label: "Last 30 Days",
        range: {Date.add(yesterday, -29), yesterday}
      },
      %{
        key: :last_90_days,
        label: "Last 90 Days",
        range: {Date.add(yesterday, -89), yesterday}
      },
      %{
        key: :all_time,
        label: "All Time",
        range: nil
      },
      %{
        key: :custom,
        label: "Custom Range",
        range: nil
      }
    ]
  end

  # ---------------------------------------------------------------------------
  # has_integrations?/1
  # ---------------------------------------------------------------------------

  @doc """
  Checks whether the scoped user has any connected integrations.

  Used by the LiveView to decide whether to render the dashboard or an
  onboarding prompt.
  """
  @spec has_integrations?(Scope.t()) :: boolean()
  def has_integrations?(%Scope{} = scope) do
    scope
    |> Integrations.list_integrations()
    |> Enum.any?()
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Resolves the distinct metric names to query, respecting platform and
  # metric_type filters. list_metric_names/2 only supports the :provider
  # filter; for metric_type we fall back to listing metrics and extracting
  # distinct names from the filtered result set.
  defp resolve_metric_names(scope, nil, nil) do
    Metrics.list_metric_names(scope)
  end

  defp resolve_metric_names(scope, platform, nil) do
    Metrics.list_metric_names(scope, provider: platform)
  end

  defp resolve_metric_names(scope, platform, metric_type) do
    opts =
      []
      |> maybe_put(:provider, platform)
      |> maybe_put(:metric_type, metric_type)

    scope
    |> Metrics.list_metrics(opts)
    |> Enum.map(& &1.metric_name)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp build_time_series(scope, metric_names, opts) do
    Enum.map(metric_names, fn name ->
      data = Metrics.query_time_series(scope, name, opts)
      %{metric_name: name, data: data}
    end)
  end

  defp build_summary_stats(scope, metric_names, opts) do
    provider_map = Metrics.list_metric_providers(scope, opts)

    Enum.map(metric_names, fn name ->
      stats = Metrics.aggregate_metrics(scope, name, opts)
      provider = Map.get(provider_map, name)
      %{metric_name: name, stats: stats, provider: provider}
    end)
  end

  # Maps compound Integration providers to their Metric provider equivalents.
  # :google is an Integration-level provider that covers both google_analytics
  # and google_ads, but Metrics are stored under the specific sub-providers.
  defp normalize_metric_provider(:google), do: [:google_analytics, :google_ads]
  defp normalize_metric_provider(other), do: other

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
