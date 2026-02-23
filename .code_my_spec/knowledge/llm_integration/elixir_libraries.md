# Elixir LLM Libraries

## LangChain for Elixir

- Package: `langchain ~> 0.5`
- Hex.pm: https://hex.pm/packages/langchain
- GitHub: https://github.com/brainlid/langchain
- Latest: 0.5.2 (February 11, 2026)
- Requires: Elixir >= 1.17 (project uses >= 1.15 — need to verify actual installed version)

### What It Does

LangChain provides high-level abstractions over LLM provider APIs:

- `LangChain.Chains.LLMChain` — manages multi-turn conversations, message history, tool execution loops
- `LangChain.ChatModels.ChatAnthropic` — Anthropic provider
- `LangChain.ChatModels.ChatOpenAI` — OpenAI provider
- `LangChain.ChatModels.ChatGoogleAI` — Gemini provider
- `LangChain.Function` — define Elixir functions the LLM can call (tool use)
- Callback system for streaming deltas and processed messages

### Setup

```elixir
# mix.exs
{:langchain, "~> 0.5"}

# config/runtime.exs
config :langchain, openai_key: System.get_env("OPENAI_API_KEY")
config :langchain, anthropic_key: System.get_env("ANTHROPIC_API_KEY")
```

### Chat with Streaming (LiveView Pattern)

The recommended LiveView pattern for streaming LLM responses:

1. LiveView spawns a `Task` to run the LLM chain
2. The `on_llm_new_delta` callback sends token deltas to the LiveView pid
3. `handle_info/2` in the LiveView appends tokens to a socket assign (streamed via LiveView streams)

```elixir
# In MetricFlow.Ai.LlmClient
def chat_stream(messages, user_pid) do
  handler = %{
    on_llm_new_delta: fn _chain, delta ->
      send(user_pid, {:llm_delta, delta.content})
    end,
    on_message_processed: fn _chain, message ->
      send(user_pid, {:llm_done, message})
    end
  }

  {:ok, chat_model} = ChatAnthropic.new(%{
    model: System.get_env("ANTHROPIC_MODEL", "claude-sonnet-4-5-20251001"),
    stream: true,
    max_tokens: 2048
  })

  LLMChain.new!(%{llm: chat_model})
  |> LLMChain.add_callback(handler)
  |> LLMChain.add_messages(messages)
  |> LLMChain.run()
end

# In MetricFlowWeb.Chat LiveView
def handle_event("send_message", %{"message" => text}, socket) do
  lv_pid = self()
  messages = build_messages(socket.assigns.chat_session, text)
  Task.start(fn -> MetricFlow.Ai.LlmClient.chat_stream(messages, lv_pid) end)
  {:noreply, assign(socket, :streaming, true)}
end

def handle_info({:llm_delta, token}, socket) do
  updated = (socket.assigns.current_response || "") <> token
  {:noreply, assign(socket, :current_response, updated)}
end

def handle_info({:llm_done, message}, socket) do
  # Persist the message, reset streaming state
  {:noreply, socket |> assign(:streaming, false) |> assign(:current_response, nil)}
end
```

### Tool Calling (Data Query Pattern)

For "ask a question, query the database" patterns, LangChain functions allow the LLM to request data:

```elixir
metrics_fn = Function.new!(%{
  name: "get_metrics",
  description: "Fetch time-series metrics for a platform and date range",
  parameters_schema: %{
    type: "object",
    properties: %{
      platform: %{type: "string", enum: ["google_analytics", "google_ads", "facebook_ads", "quickbooks"]},
      metric_name: %{type: "string"},
      start_date: %{type: "string", format: "date"},
      end_date: %{type: "string", format: "date"}
    },
    required: ["platform", "metric_name", "start_date", "end_date"]
  },
  function: fn %{"platform" => platform, "metric_name" => metric, "start_date" => s, "end_date" => e}, _ctx ->
    MetricFlow.Metrics.query_for_ai(platform, metric, s, e)
    |> Jason.encode!()
  end
})

LLMChain.new!(%{llm: chat_model})
|> LLMChain.add_tools([metrics_fn])
|> LLMChain.run(:while_needs_response)
```

This is more token-efficient than embedding all data upfront, but adds latency per tool call.

---

## InstructorLite

- Package: `instructor_lite ~> 1.2`
- Hex.pm: https://hex.pm/packages/instructor_lite
- GitHub: https://github.com/martosaur/instructor_lite
- Latest: 1.2.0 (February 1, 2026)
- Uses: `req ~> 0.5` (already in project — no extra dep needed)

### What It Does

InstructorLite coerces LLM output into validated Ecto schemas. It:

1. Generates a JSON schema from your Ecto schema definition
2. Includes that schema in the LLM prompt (as a tool or structured output constraint)
3. Casts the response into your schema using Ecto changesets
4. On validation failure, retries with the error feedback (configurable max retries)

It does **not** support streaming. Use it for structured generation tasks where you need a complete, validated JSON object.

### Setup

```elixir
# mix.exs
{:instructor_lite, "~> 1.2"}

# No extra config needed — pass api_key as adapter_context
```

### Defining an Instruction Schema

```elixir
defmodule MetricFlow.Ai.InsightResult do
  use Ecto.Schema
  use InstructorLite.Instruction

  @doc """
  Marketing analytics insight with a title, description, and recommended action.
  """
  @primary_key false
  embedded_schema do
    field :title, :string
    field :summary, :string
    field :significance, Ecto.Enum, values: [:high, :medium, :low]
    field :recommended_action, :string
    field :supporting_metrics, {:array, :string}
  end

  def validate(changeset) do
    changeset
    |> validate_required([:title, :summary, :significance, :recommended_action])
  end
end
```

### Calling InstructorLite

```elixir
def generate_insight(correlation_data, scope) do
  prompt = build_insight_prompt(correlation_data)

  InstructorLite.instruct(
    %{
      messages: [%{role: "user", content: prompt}],
      model: "claude-haiku-4-5-20251001"
    },
    response_model: MetricFlow.Ai.InsightResult,
    adapter: InstructorLite.Adapters.Anthropic,
    adapter_context: [api_key: System.fetch_env!("ANTHROPIC_API_KEY")],
    max_retries: 2
  )
end
```

### Vega-Lite Spec Generation

For the Report Generator, InstructorLite is ideal. The Vega-Lite spec is a well-defined JSON structure, and Ecto validation can enforce required fields:

```elixir
defmodule MetricFlow.Ai.VegaLiteSpec do
  use Ecto.Schema
  use InstructorLite.Instruction

  @doc "A Vega-Lite v5 specification for a marketing analytics chart"
  @primary_key false
  embedded_schema do
    field :schema_url, :string  # "$schema"
    field :title, :string
    field :description, :string
    field :mark_type, :string   # "bar", "line", "point", etc.
    # The full spec is complex — store as a map and validate at a higher level
    field :spec_json, :map
  end

  def validate(changeset) do
    changeset
    |> validate_required([:mark_type, :spec_json])
    |> validate_change(:spec_json, fn :spec_json, v ->
      if Map.has_key?(v, "$schema"), do: [], else: [spec_json: "must include $schema"]
    end)
  end
end
```

---

## Comparison Summary

| Capability | LangChain | InstructorLite | Raw Req |
|---|---|---|---|
| Multi-turn chat | Yes (LLMChain) | No | Manual |
| Streaming | Yes (callbacks) | No | Manual SSE |
| Tool / function calling | Yes | No | Manual |
| Structured output | Via tools | Yes (Ecto schemas) | Manual |
| Automatic retry on validation | No | Yes | Manual |
| Providers | OpenAI, Claude, Gemini, Ollama, + | OpenAI, Claude, Gemini, Grok | Any |
| Req usage | Yes (internal) | Yes (optional, default) | Direct |
| Elixir version req | >= 1.17 | ~1.15+ (unspecified) | Any |

### Recommendation: Use Both

- Use **LangChain** for the `ChatSession` / `LlmClient` modules (conversational chat, streaming to LiveView, tool-based data retrieval)
- Use **InstructorLite** for `InsightsGenerator` and `ReportGenerator` (structured JSON output, Ecto validation, retries)

This avoids reimplementing streaming in InstructorLite and avoids reimplementing Ecto-based validation in LangChain.
