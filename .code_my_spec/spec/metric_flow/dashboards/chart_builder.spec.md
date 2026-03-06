# MetricFlow.Dashboards.ChartBuilder

Pure module for building Vega-Lite chart specifications. Constructs time series line charts, bar charts, and summary stats visualizations using the vega_lite Elixir package. All functions are pure transformations — they accept data and return a Vega-Lite spec map with no side effects. The generated specs are JSON-encodable and intended to be passed to vega-embed on the client.

## Type

module

## Delegates

## Functions

### build_time_series_spec/2

Builds a Vega-Lite line chart spec for a single metric's time series data. The returned map is JSON-encodable and ready to be passed to vega-embed on the client.

```elixir
@spec build_time_series_spec(String.t(), list(%{date: Date.t(), value: float()})) :: map()
```

**Process**:
1. Convert each data point's date from a Date struct to an ISO 8601 string (using Date.to_iso8601/1) for Vega-Lite temporal compatibility
2. Create a new VegaLite spec with title set to the metric_name argument
3. Load the converted data points via VegaLite.data_from_values/2
4. Set the mark to :line with the point: true option to render data point dots
5. Encode the x-axis to the "date" field with type: :temporal
6. Encode the y-axis to the "value" field with type: :quantitative
7. Call VegaLite.to_spec/1 to convert the builder struct to a JSON-encodable map and return it

**Test Assertions**:
- returns a map with a "$schema" key pointing to a Vega-Lite schema URL
- returned map includes a "mark" key configured for a line chart
- returned map includes an "encoding" key with "x" mapped to the "date" field with temporal type
- returned map includes an "encoding" key with "y" mapped to the "value" field with quantitative type
- title in the returned spec matches the metric_name argument
- data values in the spec contain the provided data points with dates serialized as ISO 8601 strings
- returns a valid Vega-Lite spec when given an empty data list
- returns a valid Vega-Lite spec when given a single data point

### build_bar_chart_spec/2

Builds a Vega-Lite bar chart spec for category comparison, such as metrics grouped by platform. The returned map is JSON-encodable and ready to be passed to vega-embed on the client.

```elixir
@spec build_bar_chart_spec(String.t(), list(%{category: String.t(), value: float()})) :: map()
```

**Process**:
1. Create a new VegaLite spec with title set to the title argument
2. Load the data points via VegaLite.data_from_values/2
3. Set the mark to :bar
4. Encode the x-axis to the "category" field with type: :nominal
5. Encode the y-axis to the "value" field with type: :quantitative
6. Call VegaLite.to_spec/1 to convert the builder struct to a JSON-encodable map and return it

**Test Assertions**:
- returns a map with a "$schema" key pointing to a Vega-Lite schema URL
- returned map includes a "mark" key configured for a bar chart
- returned map includes an "encoding" key with "x" mapped to the "category" field with nominal type
- returned map includes an "encoding" key with "y" mapped to the "value" field with quantitative type
- title in the returned spec matches the title argument
- returns a valid Vega-Lite spec when given an empty data list
- returns a valid Vega-Lite spec when given a single category data point

### build_summary_card_spec/2

Builds a simple map suitable for rendering as a stat card. Returns a plain Elixir map containing the metric name and aggregated statistics rather than a full Vega-Lite chart spec, since summary cards are rendered as text/numbers rather than as a visual chart.

```elixir
@spec build_summary_card_spec(String.t(), %{sum: float(), avg: float(), min: float(), max: float(), count: integer()}) :: map()
```

**Process**:
1. Build and return a plain map with the following keys: metric_name set to the metric_name argument, sum, avg, min, max, and count taken from the stats argument

**Test Assertions**:
- returns a map with a metric_name key matching the metric_name argument
- returned map includes the sum value from stats
- returned map includes the avg value from stats
- returned map includes the min value from stats
- returned map includes the max value from stats
- returned map includes the count value from stats
- handles stats where all numeric values are zero
- handles stats where count is 0

## Dependencies

- VegaLite
