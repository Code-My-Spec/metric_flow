defmodule MetricFlow.Dashboards.A2ui do
  @moduledoc """
  Shared A2UI component typing, query and render logic.

  `DashboardLive.Editor` (building) and `DashboardLive.Show` (the read-only
  view page) both read the same `a2ui_spec` component shape and both fetch
  live data for it the same way; this is the one place that shape and that
  fetch are defined, so the two pages can't drift on what a component means
  or how it's queried (main's review at 76d8303 found exactly that drift:
  Show's own copy had no "table" clause and never threaded a platform
  filter through).
  """

  alias MetricFlow.Dashboards
  alias MetricFlow.Metrics

  @doc "A component's display title, falling back to its bound metric name, humanized."
  @spec component_title(map()) :: String.t()
  def component_title(%{"title" => title}) when is_binary(title), do: title

  def component_title(component) do
    case component_metric(component) do
      nil -> "Untitled"
      metric -> humanize_metric_name(metric)
    end
  end

  defp humanize_metric_name(metric_name) do
    metric_name
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Resolves the metric key a component is bound to: the chat-built
  `{"query" => {"metric" => _}}` shape, the ad-hoc legacy
  `{"metric_name" => _}` shape (`DashboardsRepository.replace_dashboard_visualizations/3`'s
  own default for a dashboard saved before Story 74's A2UI rebuild), or a
  frozen Vega-Lite spec's named data source (the old manual/library-insert
  flow, retired in Story 75 but possibly still stored on an existing
  dashboard) -- the same shapes `DashboardLive.Editor` has always had to
  resolve when loading a dashboard's legacy `Visualization` rows. Nil only
  when none of those apply; `build_chart_render/5` renders `:no_data`
  rather than ever querying with it.
  """
  @spec component_metric(map()) :: String.t() | nil
  def component_metric(%{"query" => %{"metric" => metric}}) when is_binary(metric), do: metric

  def component_metric(%{"metric_name" => metric_name}) when is_binary(metric_name),
    do: metric_name

  def component_metric(component) do
    case named_vega_lite_source(component) do
      [name | _] -> name
      [] -> nil
    end
  end

  defp named_vega_lite_source(%{"data" => %{"name" => name}}), do: [name]

  defp named_vega_lite_source(%{"layer" => layers}) when is_list(layers) do
    Enum.flat_map(layers, &named_vega_lite_source/1)
  end

  defp named_vega_lite_source(_), do: []

  @doc "A component's chart_type (\"text\", \"table\", or an ECharts chart type), defaulting to \"line\"."
  @spec component_chart_type(map()) :: String.t()
  def component_chart_type(component), do: component_chart_type_or_nil(component) || "line"

  @doc """
  Like `component_chart_type/1` but returns nil (rather than defaulting)
  for anything that doesn't look like an A2UI component at all, so a
  caller juggling both an A2UI component and a legacy Vega-Lite spec can
  fall through to its own handling.
  """
  @spec component_chart_type_or_nil(map()) :: String.t() | nil
  def component_chart_type_or_nil(%{"type" => "stat"}), do: "text"
  def component_chart_type_or_nil(%{"type" => "table"}), do: "table"

  def component_chart_type_or_nil(%{"type" => "chart", "chartType" => type})
      when is_binary(type),
      do: type

  def component_chart_type_or_nil(%{"type" => "chart"}), do: "line"
  def component_chart_type_or_nil(_component), do: nil

  @doc """
  Queries a metric and builds its render-time payload:
  `{:stat, formatted_total} | {:table, [{date, value}]} | {:chart, echarts_option} | {:no_data, nil}`.

  Never reads data out of the component itself -- always fetched live, so a
  chat-built widget (named data source only) and a legacy Vega-Lite row
  (possibly carrying old embedded data) render identically. `date_range` is
  the filter's raw "7"/"30"/"90" string.
  """
  @spec build_chart_render(
          String.t(),
          String.t(),
          MetricFlow.Users.Scope.t(),
          String.t(),
          atom() | nil
        ) ::
          {:stat, String.t()} | {:table, list()} | {:chart, map()} | {:no_data, nil}
  def build_chart_render(metric, chart_type, scope, date_range, platform \\ nil)

  def build_chart_render(nil, _chart_type, _scope, _date_range, _platform), do: {:no_data, nil}

  def build_chart_render(metric, chart_type, scope, date_range, platform) do
    case query_values(metric, scope, date_range, platform) do
      [] -> {:no_data, nil}
      values -> render_from_values(chart_type, values)
    end
  end

  defp query_values(metric, scope, date_range, platform) do
    opts = [date_range: date_range_for(date_range)] |> maybe_put_provider(platform)

    scope
    |> Metrics.query_time_series(metric, opts)
    |> Enum.map(fn %{date: date, value: value} -> {Date.to_iso8601(date), value} end)
  end

  defp maybe_put_provider(opts, nil), do: opts
  defp maybe_put_provider(opts, platform), do: Keyword.put(opts, :provider, platform)

  defp render_from_values("text", values) do
    total = Enum.reduce(values, 0, fn {_date, value}, acc -> acc + value end)
    {:stat, format_stat_value(total)}
  end

  defp render_from_values("table", values) do
    {:table, Enum.map(values, fn {date, value} -> {date, format_table_value(value)} end)}
  end

  defp render_from_values(chart_type, values) do
    option = %{
      "xAxis" => %{"type" => "category", "data" => Enum.map(values, &elem(&1, 0))},
      "yAxis" => %{"type" => "value"},
      "series" => [echarts_series(chart_type, Enum.map(values, &elem(&1, 1)))]
    }

    {:chart, option}
  end

  defp echarts_series("bar", data), do: %{"type" => "bar", "data" => data}
  defp echarts_series("area", data), do: %{"type" => "line", "data" => data, "areaStyle" => %{}}
  defp echarts_series(_, data), do: %{"type" => "line", "data" => data}

  # A query's value is a float (the metrics table's column type); a table
  # cell should read like the editor's "4005", not an unformatted
  # "4005.0" -- rounded to a whole number, same as the stat tile's total,
  # but without the stat's thousands-separator (a table is many rows, not
  # one headline figure).
  defp format_table_value(value) when is_float(value) or is_integer(value) do
    value |> round() |> Integer.to_string()
  end

  defp format_table_value(value), do: value

  @doc "Formats a stat tile's total with thousands separators, e.g. 125706 -> \"125,706\"."
  @spec format_stat_value(number()) :: String.t()
  def format_stat_value(value) do
    value
    |> round()
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  @doc "Maps a filter's \"7\"/\"30\"/\"90\" range string to a {start, end} date tuple."
  @spec date_range_for(String.t()) :: {Date.t(), Date.t()}
  def date_range_for(range_str) do
    key =
      case range_str do
        "7" -> :last_7_days
        "90" -> :last_90_days
        _ -> :last_30_days
      end

    Dashboards.available_date_ranges()
    |> Enum.find(&(&1.key == key))
    |> Map.fetch!(:range)
  end

  @doc "Every provider the scope's account has any metric data from."
  @spec available_platforms(MetricFlow.Users.Scope.t()) :: [atom()]
  def available_platforms(scope) do
    scope
    |> Metrics.list_metric_providers()
    |> Map.values()
    |> Enum.uniq()
    |> Enum.sort()
  end

  @doc "A platform atom's display label, e.g. :google_ads -> \"Google Ads\"."
  @spec platform_display_name(atom()) :: String.t()
  def platform_display_name(platform) when is_atom(platform) do
    platform
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end
end
