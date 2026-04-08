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
    exports: [Dashboard, Visualization]

  alias MetricFlow.Dashboards.ChartBuilder
  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Dashboards.DashboardsRepository
  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Dashboards.VisualizationsRepository
  alias MetricFlow.Integrations
  alias MetricFlow.Metrics
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Delegated repository functions — Dashboards
  # ---------------------------------------------------------------------------

  defdelegate get_dashboard(scope, id), to: DashboardsRepository

  @doc "Returns all dashboards for the scoped user."
  @spec list_dashboards(Scope.t()) :: list(Dashboard.t())
  defdelegate list_dashboards(scope), to: DashboardsRepository

  @doc "Returns all system-provided built-in dashboards."
  @spec list_canned_dashboards() :: list(Dashboard.t())
  defdelegate list_canned_dashboards(), to: DashboardsRepository

  @doc """
  Retrieves a single dashboard for the scoped user by ID with its
  dashboard_visualizations and associated visualizations preloaded.

  Returns `{:ok, dashboard}` when found, or `{:error, :not_found}` when the
  dashboard does not exist or belongs to a different user.
  """
  @spec get_dashboard_with_visualizations(Scope.t(), integer()) ::
          {:ok, Dashboard.t()} | {:error, :not_found}
  defdelegate get_dashboard_with_visualizations(scope, id), to: DashboardsRepository

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

  @doc """
  Replaces all visualizations for a dashboard in a single transaction.

  Each visualization entry must be a map with `:metric_name`, `:chart_type`,
  and `:position` keys. Existing visualizations for the dashboard are deleted
  and replaced with new records. Returns `:ok` on success or
  `{:error, reason}` on failure.
  """
  @spec replace_dashboard_visualizations(Scope.t(), Dashboard.t(), list(map())) ::
          :ok | {:error, term()}
  defdelegate replace_dashboard_visualizations(scope, dashboard, visualizations),
    to: DashboardsRepository

  @doc """
  Deletes a user-owned dashboard if it belongs to the scoped user.

  Returns `{:ok, dashboard}` on success, `{:error, :not_found}` when the
  dashboard doesn't exist or belongs to another user, and
  `{:error, :unauthorized}` when the dashboard is built-in.
  """
  @spec delete_dashboard(Scope.t(), integer()) ::
          {:ok, Dashboard.t()} | {:error, :not_found | :unauthorized}
  def delete_dashboard(%Scope{} = scope, id) do
    with {:ok, dashboard} <- DashboardsRepository.get_dashboard(scope, id) do
      delete_if_not_built_in(dashboard)
    end
  end

  @doc "Returns an Ecto changeset for a Dashboard."
  @spec dashboard_changeset(Dashboard.t(), map()) :: Ecto.Changeset.t()
  def dashboard_changeset(%Dashboard{} = dashboard, attrs) do
    Dashboard.changeset(dashboard, attrs)
  end

  # ---------------------------------------------------------------------------
  # Visualization functions
  # ---------------------------------------------------------------------------

  @doc "Retrieves a single visualization for the scoped user by ID."
  @spec get_visualization(Scope.t(), integer()) ::
          {:ok, Visualization.t()} | {:error, :not_found}
  defdelegate get_visualization(scope, id), to: VisualizationsRepository

  @doc "Returns all visualizations for the scoped user."
  @spec list_visualizations(Scope.t()) :: list(Visualization.t())
  defdelegate list_visualizations(scope), to: VisualizationsRepository

  @doc "Creates a new standalone visualization for the scoped user."
  @spec save_visualization(Scope.t(), map()) ::
          {:ok, Visualization.t()} | {:error, Ecto.Changeset.t()}
  def save_visualization(%Scope{} = scope, attrs) do
    VisualizationsRepository.create_visualization(scope, attrs)
  end

  @doc "Updates an existing visualization with the given attributes."
  @spec update_visualization(Scope.t(), Visualization.t(), map()) ::
          {:ok, Visualization.t()} | {:error, Ecto.Changeset.t()}
  def update_visualization(%Scope{}, %Visualization{} = visualization, attrs) do
    VisualizationsRepository.update_visualization(visualization, attrs)
  end

  @doc """
  Deletes a visualization owned by the scoped user.

  Returns `{:ok, visualization}` on success, `{:error, :not_found}` when the
  visualization doesn't exist or belongs to another user.
  """
  @spec delete_visualization(Scope.t(), integer()) ::
          {:ok, Visualization.t()} | {:error, :not_found}
  def delete_visualization(%Scope{} = scope, id) do
    with {:ok, visualization} <- VisualizationsRepository.get_visualization(scope, id) do
      case VisualizationsRepository.delete_visualization(visualization) do
        {:ok, deleted} -> {:ok, deleted}
        {:error, _changeset} -> {:error, :not_found}
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Visualization metrics (many-to-many metric binding)
  # ---------------------------------------------------------------------------

  @doc """
  Sets the bound metrics for a visualization, replacing any existing bindings.
  """
  @spec set_visualization_metrics(Visualization.t(), [String.t()]) :: :ok
  defdelegate set_visualization_metrics(visualization, metric_names),
    to: VisualizationsRepository

  @doc """
  Returns the list of metric names bound to a visualization.
  """
  @spec get_visualization_metric_names(Visualization.t()) :: [String.t()]
  defdelegate get_visualization_metric_names(visualization),
    to: VisualizationsRepository

  @doc """
  Builds a render-ready Vega-Lite spec by fetching fresh data for all
  bound metrics and injecting it into the spec template.

  For single-metric visualizations, data is injected as `data.values`.
  For multi-metric, each data point includes a `metric` field for
  color-coding separate series.
  """
  @spec build_render_spec(Scope.t(), Visualization.t()) :: map()
  def build_render_spec(%Scope{} = scope, %Visualization{} = viz) do
    metric_names = get_visualization_metric_names(viz)
    spec = viz.vega_spec || %{}

    data = fetch_and_combine_metrics(scope, metric_names)
    spec = Map.put(spec, "data", %{"values" => data})

    # For multi-metric, add color encoding if not already present
    if length(metric_names) > 1 do
      encoding = Map.get(spec, "encoding", %{})

      unless Map.has_key?(encoding, "color") do
        encoding = Map.put(encoding, "color", %{"field" => "metric", "type" => "nominal"})
        Map.put(spec, "encoding", encoding)
      else
        spec
      end
    else
      spec
    end
  end

  defp fetch_and_combine_metrics(scope, metric_names) do
    {start_date, end_date} = default_date_range()

    metric_names
    |> Enum.flat_map(fn name ->
      Metrics.query_time_series(scope, name, date_range: {start_date, end_date})
      |> Enum.map(fn %{date: date, value: value} ->
        %{"date" => Date.to_string(date), "value" => value, "metric" => name}
      end)
    end)
  end

  @doc "Returns an Ecto changeset for validating a Visualization name field."
  @spec visualization_name_changeset(String.t()) :: Ecto.Changeset.t()
  def visualization_name_changeset(name) do
    import Ecto.Changeset

    {%{}, %{name: :string}}
    |> cast(%{name: name}, [:name])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 255)
  end

  # ---------------------------------------------------------------------------
  # list_available_metrics/1
  # ---------------------------------------------------------------------------

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
  Builds a Vega-Lite JSON specification for a multi-series overlay line chart.
  Multiple metrics appear as differently colored lines on a single chart.
  Delegates to MetricFlow.Dashboards.ChartBuilder.build_multi_series_spec/2.
  """
  @spec build_multi_series_chart_spec(
          String.t(),
          list(%{metric_name: String.t(), data: list(%{date: Date.t(), value: float()})})
        ) :: map()
  defdelegate build_multi_series_chart_spec(title, time_series),
    to: ChartBuilder,
    as: :build_multi_series_spec

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

  defp delete_if_not_built_in(%Dashboard{built_in: true}), do: {:error, :unauthorized}

  defp delete_if_not_built_in(%Dashboard{} = dashboard) do
    case DashboardsRepository.delete_dashboard(dashboard) do
      {:ok, deleted} -> {:ok, deleted}
      {:error, _changeset} -> {:error, :not_found}
    end
  end

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
