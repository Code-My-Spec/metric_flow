defmodule MetricFlow.Dashboards.ChartBuilder do
  @moduledoc """
  Pure module for building Vega-Lite chart specifications.

  Constructs time series line charts, bar charts, and summary stats
  visualizations using the vega_lite Elixir package. All functions are pure
  transformations — they accept data and return a Vega-Lite spec map with no
  side effects. The generated specs are JSON-encodable and intended to be
  passed to vega-embed on the client.
  """

  alias VegaLite, as: Vl

  # Dark theme config matching DaisyUI dark theme colors
  @dark_theme %{
    "background" => "transparent",
    "title" => %{"color" => "#a6adbb"},
    "axis" => %{
      "labelColor" => "#a6adbb",
      "titleColor" => "#a6adbb",
      "gridColor" => "#2a323c",
      "domainColor" => "#3d4451",
      "tickColor" => "#3d4451"
    },
    "legend" => %{
      "labelColor" => "#a6adbb",
      "titleColor" => "#a6adbb"
    },
    "view" => %{
      "stroke" => "transparent"
    }
  }

  @doc """
  Builds a Vega-Lite line chart spec for a single metric's time series data.

  Dates are converted from Date structs to ISO 8601 strings for Vega-Lite
  temporal compatibility. The returned map is JSON-encodable and ready to be
  passed to vega-embed on the client.
  """
  @spec build_time_series_spec(String.t(), list(%{date: Date.t(), value: float()})) :: map()
  def build_time_series_spec(metric_name, data) do
    values =
      Enum.map(data, fn %{date: date, value: value} ->
        %{"date" => Date.to_iso8601(date), "value" => value}
      end)

    Vl.new(title: metric_name, width: "container", height: 400)
    |> Vl.data_from_values(values)
    |> Vl.mark(:line, point: true)
    |> Vl.encode_field(:x, "date", type: :temporal)
    |> Vl.encode_field(:y, "value", type: :quantitative)
    |> Vl.to_spec()
    |> apply_dark_theme()
  end

  @doc """
  Builds a Vega-Lite multi-series line chart spec that overlays multiple metrics
  as differently colored lines on a single chart. Each metric becomes a separate
  colored line identified by name in the legend.

  The input is a title and a list of `%{metric_name, data}` entries (the same
  shape returned by `Dashboards.get_dashboard_data/2` in its `:time_series` key).
  Data points are flattened into a single dataset with a "metric" field for color
  encoding.
  """
  @spec build_multi_series_spec(
          String.t(),
          list(%{metric_name: String.t(), data: list(%{date: Date.t(), value: float()})})
        ) :: map()
  def build_multi_series_spec(title, time_series) do
    values =
      Enum.flat_map(time_series, fn %{metric_name: metric_name, data: data} ->
        Enum.map(data, fn %{date: date, value: value} ->
          %{"date" => Date.to_iso8601(date), "value" => value, "metric" => metric_name}
        end)
      end)

    Vl.new(title: title, width: "container", height: 400)
    |> Vl.data_from_values(values)
    |> Vl.mark(:line, point: true, tooltip: true)
    |> Vl.encode_field(:x, "date", type: :temporal)
    |> Vl.encode_field(:y, "value", type: :quantitative, scale: [type: "symlog"])
    |> Vl.encode_field(:color, "metric", type: :nominal)
    |> Vl.to_spec()
    |> apply_dark_theme()
  end

  @doc """
  Builds a Vega-Lite area chart spec for a single metric's time series data.

  Same structure as the line chart but uses an area mark with a semi-transparent
  fill. Dates are converted from Date structs to ISO 8601 strings for Vega-Lite
  temporal compatibility.
  """
  @spec build_area_chart_spec(String.t(), list(%{date: Date.t(), value: float()})) :: map()
  def build_area_chart_spec(metric_name, data) do
    values =
      Enum.map(data, fn %{date: date, value: value} ->
        %{"date" => Date.to_iso8601(date), "value" => value}
      end)

    Vl.new(title: metric_name, width: "container", height: 400)
    |> Vl.data_from_values(values)
    |> Vl.mark(:area, line: true, opacity: 0.3)
    |> Vl.encode_field(:x, "date", type: :temporal)
    |> Vl.encode_field(:y, "value", type: :quantitative)
    |> Vl.to_spec()
    |> apply_dark_theme()
  end

  @doc """
  Builds a Vega-Lite bar chart spec for category comparison, such as metrics
  grouped by platform.

  The returned map is JSON-encodable and ready to be passed to vega-embed on
  the client.
  """
  @spec build_bar_chart_spec(String.t(), list(%{category: String.t(), value: float()})) :: map()
  def build_bar_chart_spec(title, data) do
    Vl.new(title: title)
    |> Vl.data_from_values(data)
    |> Vl.mark(:bar)
    |> Vl.encode_field(:x, "category", type: :nominal)
    |> Vl.encode_field(:y, "value", type: :quantitative)
    |> Vl.to_spec()
  end

  @doc """
  Builds a simple map suitable for rendering as a stat card.

  Returns a plain Elixir map containing the metric name and aggregated
  statistics rather than a full Vega-Lite chart spec, since summary cards are
  rendered as text/numbers rather than as a visual chart.
  """
  @spec build_summary_card_spec(String.t(), %{
          sum: float(),
          avg: float(),
          min: float(),
          max: float(),
          count: integer()
        }) :: map()
  def build_summary_card_spec(metric_name, %{
        sum: sum,
        avg: avg,
        min: min,
        max: max,
        count: count
      }) do
    %{
      metric_name: metric_name,
      sum: sum,
      avg: avg,
      min: min,
      max: max,
      count: count
    }
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp apply_dark_theme(spec) do
    Map.put(spec, "config", @dark_theme)
  end
end
