defmodule MetricFlow.Dashboards.QueryBuilder do
  @moduledoc """
  Pure module that builds structured query params from filter inputs.

  Translates user-facing filter values — date range, platform atoms, and metric
  name strings — into the keyword list format consumed by
  `MetricFlow.Metrics` query functions. All functions are pure transformations
  with no side effects.
  """

  @typedoc """
  A structured set of query parameters ready to pass to Metrics functions.

  - `:date_range` — `{start_date, end_date}` tuple, or `nil` for all time.
  - `:provider` — a single provider atom, a list of provider atoms, or `nil`
    for all providers.
  - `:metric_names` — a list of metric name strings to include, or `[]` for
    all metrics.
  """
  @type query_params :: %{
          date_range: {Date.t(), Date.t()} | nil,
          provider: atom() | [atom()] | nil,
          metric_names: [String.t()]
        }

  @doc """
  Builds a `query_params` map from a keyword list of raw filter inputs.

  Accepted options:
  - `:date_range` — `{start_date, end_date}` tuple or `nil`. Defaults to `nil`.
  - `:platform` — a provider atom or list of provider atoms. `nil` means all
    platforms. Defaults to `nil`.
  - `:metric_names` — a list of metric name strings. `[]` means all metrics.
    Defaults to `[]`.
  """
  @spec build(keyword()) :: query_params()
  def build(opts \\ []) when is_list(opts) do
    %{
      date_range: Keyword.get(opts, :date_range),
      provider: resolve_provider(Keyword.get(opts, :platform)),
      metric_names: Keyword.get(opts, :metric_names, [])
    }
  end

  @doc """
  Converts a `query_params` map into a keyword list suitable for passing
  directly to `MetricFlow.Metrics` query functions.

  Keys with `nil` values are omitted so that downstream functions can use their
  own defaults. An empty `:metric_names` list is also omitted.
  """
  @spec to_keyword(query_params()) :: keyword()
  def to_keyword(%{date_range: date_range, provider: provider, metric_names: metric_names}) do
    []
    |> put_if_present(:date_range, date_range)
    |> put_if_present(:provider, provider)
    |> put_if_not_empty(:metric_names, metric_names)
  end

  @doc """
  Returns true when the query params contain an active date range filter.
  """
  @spec has_date_range?(query_params()) :: boolean()
  def has_date_range?(%{date_range: {%Date{}, %Date{}}}), do: true
  def has_date_range?(%{date_range: _}), do: false

  @doc """
  Returns true when the query params are filtered to specific platforms.
  """
  @spec has_platform_filter?(query_params()) :: boolean()
  def has_platform_filter?(%{provider: nil}), do: false
  def has_platform_filter?(%{provider: []}), do: false
  def has_platform_filter?(%{provider: _}), do: true

  @doc """
  Returns true when the query params are filtered to specific metric names.
  """
  @spec has_metric_name_filter?(query_params()) :: boolean()
  def has_metric_name_filter?(%{metric_names: []}), do: false
  def has_metric_name_filter?(%{metric_names: [_ | _]}), do: true

  @doc """
  Merges new filter options into an existing `query_params` map, returning a
  new params map with the updated values.

  Accepts the same options as `build/1`.
  """
  @spec merge(query_params(), keyword()) :: query_params()
  def merge(%{} = params, opts) when is_list(opts) do
    opts
    |> Enum.reduce(params, fn
      {:date_range, value}, acc -> %{acc | date_range: value}
      {:platform, value}, acc -> %{acc | provider: resolve_provider(value)}
      {:metric_names, value}, acc -> %{acc | metric_names: value}
      _unknown, acc -> acc
    end)
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  # Normalises the :platform input into the provider representation used by the
  # Metrics context. Compound integration providers (like :google) map to the
  # list of their constituent metric providers.
  defp resolve_provider(nil), do: nil
  defp resolve_provider([]), do: nil
  defp resolve_provider(:google), do: [:google_analytics, :google_ads]
  defp resolve_provider(providers) when is_list(providers), do: providers
  defp resolve_provider(provider) when is_atom(provider), do: provider

  defp put_if_present(keyword, _key, nil), do: keyword
  defp put_if_present(keyword, key, value), do: Keyword.put(keyword, key, value)

  defp put_if_not_empty(keyword, _key, []), do: keyword
  defp put_if_not_empty(keyword, key, value), do: Keyword.put(keyword, key, value)
end
