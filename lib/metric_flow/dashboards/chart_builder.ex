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

    Vl.new(title: metric_name)
    |> Vl.data_from_values(values)
    |> Vl.mark(:line, point: true)
    |> Vl.encode_field(:x, "date", type: :temporal)
    |> Vl.encode_field(:y, "value", type: :quantitative)
    |> Vl.to_spec()
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
end
