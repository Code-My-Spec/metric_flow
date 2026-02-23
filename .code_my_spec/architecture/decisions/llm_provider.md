# LLM Provider and Integration Strategy

## Status

Proposed

## Context

MetricFlow requires LLM capabilities in three distinct areas within the `MetricFlow.Ai` context:

1. **AI Chat for Data Exploration** — A conversational interface where users ask questions about their marketing metrics (Google Analytics traffic, Google Ads spend, Facebook Ads ROI, QuickBooks revenue). Requires streaming responses for good UX, multi-turn conversational memory, and the ability to reference time-series tabular data.

2. **AI Insights and Suggestions** — Automated analysis of correlation results and metric trends, generating structured actionable suggestions with user-facing feedback tracking. Requires reliable JSON output conforming to a known schema; latency is less critical since generation can be batched.

3. **LLM-Generated Custom Reports** — Natural language descriptions translated into Vega-Lite v5 JSON specifications for custom chart generation. Requires strict JSON schema compliance; an invalid or malformed spec breaks the visualization.

The project already uses `req ~> 0.5` as its HTTP client, `jason ~> 1.2` for JSON, `oban ~> 2.2` for background jobs, and `phoenix_live_view ~> 1.1.0` for the frontend. Any LLM integration must fit this existing stack without introducing redundant HTTP clients or conflicting JSON libraries.

The `MetricFlow.Ai` context is greenfield — no provider is currently in use and no AI source files exist in `lib/`.

---

## Options Considered

### Option 1: Anthropic Claude as Primary Provider

**Pros:**
- 200K token context window comfortably holds 90 days of multi-platform metrics inline in the prompt (~45–50K tokens including conversation history), with substantial headroom
- Native Structured Outputs (in public beta as of November 2025) guarantees JSON schema compliance for Vega-Lite spec generation
- Extended thinking mode available on Claude 3.7 Sonnet for complex correlation reasoning
- Prompt caching (0.1x read price) significantly reduces cost for shared system prompts across a chat session
- Claude Haiku 4.5 ($1.00/$5.00 per million tokens) provides a cost-efficient tier for batch insights generation
- Claude Sonnet 4.5 ($3.00/$15.00 per million tokens) is the best available balance of quality and cost for interactive chat

**Cons:**
- Native Structured Outputs still in beta; InstructorLite's tool-call approach is production-proven as a fallback
- Vendor lock-in if abstraction layer is not maintained

### Option 2: OpenAI GPT-4o / GPT-5 as Primary Provider

**Pros:**
- Mature ecosystem; most Elixir LLM library examples and tutorials reference OpenAI
- Native JSON schema enforcement (`response_format: json_schema`) is the original implementation — well-tested in production
- GPT-5 at $1.25/$10.00 per million tokens is cost-competitive with Claude Haiku 4.5
- LangChain for Elixir's `ChatOpenAI` integration is the most battle-tested provider adapter

**Cons:**
- 128K context window is smaller than Claude's 200K. Sufficient for the expected 45–50K prompt size, but leaves less headroom for longer sessions or larger date ranges
- GPT-4o at $5.00/$20.00 per million is significantly more expensive than Claude Sonnet 4.5 for equivalent quality
- No pre-existing relationship with the OpenAI API; MetricFlow already has a GCP relationship through Google Analytics and Ads OAuth integrations

### Option 3: Google Gemini as Primary Provider

**Pros:**
- 1M token context window — far exceeds requirements; could embed years of raw metrics
- Gemini 2.5 Flash at $0.15/$0.60 per million tokens is dramatically cheaper than both Claude and GPT for bulk operations
- MetricFlow already has a GCP relationship for Google Analytics and Google Ads OAuth; Gemini API billing could be consolidated on the same GCP project

**Cons:**
- Less mature Elixir ecosystem support; LangChain's `ChatGoogleAI` integration is newer and less tested
- Community evidence of Claude and GPT outperforming Gemini on complex analytical reasoning tasks, which is core to MetricFlow's use case
- Gemini Flash's low cost comes with tradeoffs in reasoning quality that may surface in nuanced marketing attribution analysis

### Option 4: Build Directly on Req Without an Abstraction Library

**Pros:**
- Zero new dependencies beyond `req` (already in project)
- Full control over request construction, retry logic, and response parsing

**Cons:**
- Significant undifferentiated implementation work: SSE streaming parsing, conversational message history management, tool-call execution loops, schema validation and retries
- Harder to switch providers later if bound to a hand-rolled client
- Delays delivery of the `MetricFlow.Ai` context features

### Option 5: LangChain for Elixir Alone (No InstructorLite)

**Pros:**
- Single library for all three feature areas
- LangChain supports tool-calling patterns that can produce structured output

**Cons:**
- LangChain does not provide Ecto-schema-based validation or automatic retry on malformed output
- Implementing Vega-Lite spec validation and retry loops on top of LangChain duplicates what InstructorLite already provides
- Increases surface area of `LlmClient` module with logic that belongs in a dedicated structured-output layer

### Option 6: InstructorLite Alone (No LangChain)

**Pros:**
- Smaller dependency surface
- InstructorLite's Req adapter aligns directly with the project's HTTP client

**Cons:**
- InstructorLite explicitly does not support streaming — ruling out the chat interface's primary UX requirement
- No conversational memory management — would need to be hand-rolled
- No tool/function calling support — limits the data retrieval patterns available for the chat context

---

## Decision

**Primary LLM provider: Anthropic Claude**

**Elixir library: ReqLLM** ([hexdocs](https://hexdocs.pm/req_llm/ReqLLM.html))

### Provider Rationale

Anthropic Claude is selected as the primary provider. The 200K context window, proven quality on
analytical reasoning tasks, and competitive pricing with Haiku/Sonnet tiering make it the
strongest fit for MetricFlow's requirements.

Model selection via ReqLLM's provider:model syntax:

- **`"anthropic:claude-sonnet-4-5"`** — Interactive chat and report generation (best quality/cost)
- **`"anthropic:claude-haiku-4-5"`** — Batch insights generation (cost-efficient)

ReqLLM's multi-provider support means switching to OpenAI or Gemini is a model string change,
not a code rewrite.

### Library Rationale

**ReqLLM replaces both LangChain and InstructorLite** with a single library that covers all
three MetricFlow AI use cases:

| Use Case | ReqLLM Function | Previously |
|----------|----------------|------------|
| AI Chat (streaming) | `stream_text/3` | LangChain `LLMChain.run/2` |
| AI Insights (structured) | `generate_object/4` | InstructorLite |
| Report Generation (Vega-Lite JSON) | `generate_object/4` | InstructorLite |
| Tool/function calling | `tool/1` | LangChain tool callbacks |

**Why ReqLLM over LangChain + InstructorLite:**

1. **Single dependency** instead of two — reduces dependency surface and avoids managing two
   different API abstractions for the same provider
2. **Built on Finch** — same HTTP connection pool as Req, no Tesla dependency introduced.
   Compatible with ReqCassette for test recording of LLM API calls
3. **Unified model specification** — `"anthropic:claude-sonnet-4-5"` syntax works across all
   functions (text, streaming, structured output, embeddings)
4. **Streaming with metadata** — `stream_text/3` returns a `StreamResponse` with both a lazy
   token stream and concurrent usage/metadata collection, solving the LiveView streaming pattern
   without manual Task spawning
5. **Schema-validated structured output** — `generate_object/4` supports both NimbleOptions and
   JSON Schema formats with automatic validation, replacing InstructorLite's Ecto-schema approach
6. **No Elixir version constraint** — LangChain required Elixir >= 1.17; ReqLLM does not

### Usage Patterns

**Chat streaming to LiveView:**

```elixir
# In LiveView handle_event
{:ok, response} = ReqLLM.stream_text("anthropic:claude-sonnet-4-5", messages)
stream = ReqLLM.StreamResponse.tokens(response)

# Stream tokens to the LiveView process
Task.start(fn ->
  stream
  |> Stream.each(fn token -> send(lv_pid, {:chat_token, token}) end)
  |> Stream.run()

  usage = ReqLLM.StreamResponse.usage(response)
  send(lv_pid, {:chat_complete, usage})
end)
```

**Structured insights generation:**

```elixir
schema = [
  summary: [type: :string, required: true],
  suggestions: [type: {:list, :string}, required: true],
  confidence: [type: :float, required: true]
]

ReqLLM.generate_object!(
  "anthropic:claude-haiku-4-5",
  "Analyze these correlation results: #{Jason.encode!(results)}",
  schema
)
```

**Vega-Lite report generation:**

```elixir
vega_schema = %{
  "type" => "object",
  "properties" => %{
    "$schema" => %{"type" => "string"},
    "mark" => %{},
    "encoding" => %{},
    "data" => %{}
  }
}

ReqLLM.generate_object!(
  "anthropic:claude-sonnet-4-5",
  "Generate a Vega-Lite spec for: #{user_prompt}",
  vega_schema,
  schema_format: :json_schema
)
```

---

## Consequences

### Accepted Trade-offs

- Single vendor dependency on ReqLLM. Mitigated by the library's multi-provider design — if
  ReqLLM is abandoned, the Anthropic API is straightforward to call directly with Req.
- ReqLLM is a newer library than LangChain. The simpler API surface and Finch-based HTTP stack
  make it a better architectural fit despite the shorter track record.
- Anthropic vendor dependency for the AI provider. Mitigated by ReqLLM's `provider:model` syntax
  which allows switching providers by changing a string.

### Follow-up Actions

1. Add `{:req_llm, "~> 0.x"}` to `mix.exs` (pin to latest stable version).
2. Add `ANTHROPIC_API_KEY` to secrets and `config/runtime.exs`:
   ```elixir
   config :req_llm, :anthropic_api_key, System.get_env("ANTHROPIC_API_KEY")
   ```
3. Implement `MetricFlow.Ai.LlmClient` as a thin wrapper around ReqLLM that standardizes
   model selection, system prompts, and error handling for the three use cases.
4. Implement `MetricFlow.Ai.InsightsGenerator` using `ReqLLM.generate_object/4` with a
   NimbleOptions schema for structured insight output.
5. Implement `MetricFlow.Ai.ReportGenerator` using `ReqLLM.generate_object/4` with a JSON
   Schema for Vega-Lite spec validation.
6. For chat streaming to LiveView, use `ReqLLM.stream_text/3` with `StreamResponse.tokens/1`
   piped to `send/2` for the LiveView pid. Handle `{:chat_token, token}` and
   `{:chat_complete, usage}` in `handle_info/2`.
7. Use ReqCassette to record LLM API calls in tests (ReqLLM uses Finch, compatible with
   Req's HTTP stack).
8. Evaluate prompt caching for system prompts to reduce Anthropic API costs at scale.
9. Use Oban workers for batch `InsightsGenerator` runs to avoid blocking web requests.

### Impact on Development Workflow

- Test suite: LLM calls are recorded with ReqCassette or mocked via TestRecorder. No live
  API calls in CI.
- Local development: `ANTHROPIC_API_KEY` required in `.env` for manual AI feature testing.
- Cost monitoring: `StreamResponse.usage/1` returns token counts per request; log these and
  surface in Phoenix LiveDashboard.

---

## Sources

- ReqLLM: https://hexdocs.pm/req_llm/ReqLLM.html
- Anthropic API pricing: https://platform.claude.com/docs/en/about-claude/pricing
- Anthropic Structured Outputs: https://tessl.io/blog/anthropic-brings-structured-outputs-to-claude-developer-platform-making-api-responses-more-reliable/
