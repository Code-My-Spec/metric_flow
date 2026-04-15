# Structured Output with generate_object/4

`ReqLLM.generate_object/4` replaces InstructorLite for MetricFlow's two structured-generation
use cases: AI Insights and Vega-Lite report specs. It returns a validated map rather than an
Ecto struct.

## Function Signature

```elixir
ReqLLM.generate_object(model, prompt, schema, opts \\ [])
ReqLLM.generate_object!(model, prompt, schema, opts \\ [])  # raises on error
```

The `!` variant raises `ReqLLM.Error` on failure. Use it in Oban workers where failure should
be retried by Oban's built-in retry mechanism.

## Schema Format: NimbleOptions

For structured data with simple types, express the schema as a NimbleOptions keyword list.
ReqLLM converts this to a JSON Schema internally via `ReqLLM.Schema.to_json/1`.

```elixir
schema = [
  title:             [type: :string,              required: true],
  summary:           [type: :string,              required: true],
  significance:      [type: {:in, [:high, :medium, :low]}, required: true],
  recommended_action:[type: :string,              required: true],
  supporting_metrics:[type: {:list, :string},     required: false]
]

{:ok, response} = ReqLLM.generate_object(
  "anthropic:claude-haiku-4-5",
  prompt,
  schema
)

insight = ReqLLM.Response.object(response)
# %{
#   title: "Ad spend efficiency dropped 18% in January",
#   summary: "Cost per acquisition rose while revenue held flat ...",
#   significance: :high,
#   recommended_action: "Pause underperforming Facebook ad sets ...",
#   supporting_metrics: ["facebook_ads:cpa", "quickbooks:revenue"]
# }
```

### NimbleOptions Types Available

| NimbleOptions type | JSON Schema equivalent |
|---|---|
| `:string` | `{"type": "string"}` |
| `:integer` | `{"type": "integer"}` |
| `:float` | `{"type": "number"}` |
| `:boolean` | `{"type": "boolean"}` |
| `{:list, :string}` | `{"type": "array", "items": {"type": "string"}}` |
| `{:in, [:a, :b]}` | `{"type": "string", "enum": ["a", "b"]}` |

## Schema Format: JSON Schema

For deeply nested structures (like Vega-Lite specs) that cannot be expressed in NimbleOptions,
pass a raw JSON Schema map and set `schema_format: :json_schema`.

```elixir
vega_schema = %{
  "type" => "object",
  "required" => ["$schema", "mark", "encoding", "data"],
  "properties" => %{
    "$schema" => %{"type" => "string", "const" => "https://vega.github.io/schema/vega-lite/v5.json"},
    "title"   => %{"type" => "string"},
    "description" => %{"type" => "string"},
    "mark"    => %{
      "oneOf" => [
        %{"type" => "string", "enum" => ["bar", "line", "point", "area", "arc"]},
        %{"type" => "object", "properties" => %{"type" => %{"type" => "string"}}}
      ]
    },
    "encoding" => %{"type" => "object"},
    "data"     => %{
      "type" => "object",
      "properties" => %{
        "values" => %{"type" => "array"}
      }
    }
  }
}

spec = ReqLLM.generate_object!(
  "anthropic:claude-sonnet-4-5",
  "Generate a Vega-Lite v5 bar chart spec for: #{user_prompt}",
  vega_schema,
  schema_format: :json_schema
)
|> ReqLLM.Response.object()
```

The returned map is already validated against `vega_schema`. If the model produces a spec that
fails validation, ReqLLM retries automatically (configurable, default is 2 retries).

## InsightsGenerator Module Pattern

```elixir
defmodule MetricFlow.Ai.InsightsGenerator do
  @moduledoc """
  Generates structured AI insights from correlation analysis results.
  Runs in an Oban :ai queue worker; do not call directly from web processes.
  """

  alias MetricFlow.Ai.LlmClient

  @schema [
    title:              [type: :string,              required: true],
    summary:            [type: :string,              required: true],
    significance:       [type: {:in, [:high, :medium, :low]}, required: true],
    recommended_action: [type: :string,              required: true],
    supporting_metrics: [type: {:list, :string},     required: false],
    confidence:         [type: :float,               required: true]
  ]

  @spec generate(map()) :: {:ok, map()} | {:error, term()}
  def generate(correlation_data) do
    prompt = build_prompt(correlation_data)

    ReqLLM.generate_object(LlmClient.insights_model(), prompt, @schema)
    |> case do
      {:ok, response} -> {:ok, ReqLLM.Response.object(response)}
      {:error, _} = err -> err
    end
  end

  defp build_prompt(correlation_data) do
    """
    #{LlmClient.base_system_prompt()}

    ## Task

    Analyse the following correlation results and produce a structured insight.
    Be specific about metric names and date ranges. The confidence field should
    reflect how strongly the data supports the recommendation (0.0–1.0).

    ## Correlation Data

    #{Jason.encode!(correlation_data, pretty: true)}
    """
  end
end
```

## ReportGenerator Module Pattern

```elixir
defmodule MetricFlow.Ai.ReportGenerator do
  @moduledoc """
  Translates natural language chart descriptions into Vega-Lite v5 JSON specs.
  Uses claude-sonnet-4-5 for higher accuracy on complex schema compliance.
  """

  alias MetricFlow.Ai.LlmClient

  @vega_schema %{
    "type" => "object",
    "required" => ["$schema", "mark", "encoding"],
    "properties" => %{
      "$schema" => %{
        "type" => "string",
        "const" => "https://vega.github.io/schema/vega-lite/v5.json"
      },
      "title"       => %{"type" => "string"},
      "description" => %{"type" => "string"},
      "mark"        => %{"type" => "object"},
      "encoding"    => %{"type" => "object"},
      "data"        => %{"type" => "object"},
      "transform"   => %{"type" => "array"}
    }
  }

  @spec generate(String.t(), list()) :: {:ok, map()} | {:error, term()}
  def generate(user_prompt, available_metrics) do
    prompt = build_prompt(user_prompt, available_metrics)

    ReqLLM.generate_object(
      LlmClient.chat_model(),
      prompt,
      @vega_schema,
      schema_format: :json_schema
    )
    |> case do
      {:ok, response} -> {:ok, ReqLLM.Response.object(response)}
      {:error, _} = err -> err
    end
  end

  defp build_prompt(user_prompt, available_metrics) do
    """
    #{LlmClient.base_system_prompt()}

    ## Task

    Generate a valid Vega-Lite v5 JSON specification for the following request.
    The spec must include a $schema field set to the Vega-Lite v5 URL.
    Use "data": {"values": []} as a placeholder — the application will inject real data.

    Available metric names: #{Enum.join(available_metrics, ", ")}

    ## User Request

    #{user_prompt}
    """
  end
end
```

## Oban Worker Integration

Insights generation should not run in a web request. Wrap it in an Oban worker:

```elixir
defmodule MetricFlow.Ai.Workers.InsightsWorker do
  use Oban.Worker, queue: :ai, max_attempts: 3

  alias MetricFlow.Ai.InsightsGenerator

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"correlation_id" => correlation_id}}) do
    correlation = MetricFlow.Metrics.get_correlation!(correlation_id)

    case InsightsGenerator.generate(correlation.results) do
      {:ok, insight} ->
        MetricFlow.Ai.save_insight!(correlation_id, insight)
        :ok

      {:error, reason} ->
        {:error, reason}  # Oban retries up to max_attempts
    end
  end
end
```

## Validating Vega-Lite Specs

After generation, validate the spec parses as valid JSON and at minimum contains the required
fields before rendering:

```elixir
def validate_spec(%{"$schema" => _, "mark" => _, "encoding" => _} = spec), do: {:ok, spec}
def validate_spec(_), do: {:error, :invalid_vega_spec}
```

More thorough validation can be added later using the Vega-Lite JSON Schema directly via
NimbleJSONSchema if needed, but ReqLLM's schema enforcement should catch malformed output
before it reaches this function.
