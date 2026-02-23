# LLM Integration for MetricFlow: Overview

This document summarises what was learned during provider and library research for the `MetricFlow.Ai` context. See the other files in this directory for deeper coverage of each sub-topic.

## What We Need

The `MetricFlow.Ai` context has three distinct LLM-driven features:

| Feature | Key Requirement |
|---|---|
| AI Chat (data exploration) | Streaming responses, conversational memory, tabular data in context |
| AI Insights (correlation analysis) | Structured JSON output, batch generation, no streaming needed |
| Report Generator (Vega-Lite) | Strict JSON schema compliance, Vega-Lite spec as output |

These requirements pull in different directions. Chat demands streaming and low latency. Report generation demands guaranteed schema conformance. Insights generation needs cost efficiency at scale.

## Elixir Library Options

### LangChain for Elixir (`langchain` ~> 0.5)

- Hex.pm: https://hex.pm/packages/langchain
- Latest: 0.5.2 (released February 11, 2026)
- All-time downloads: ~480K
- Requires Elixir >= 1.17

LangChain is the most feature-complete Elixir LLM library. It supports OpenAI, Anthropic Claude, Google Gemini, Ollama, Mistral, Perplexity, and xAI Grok. It provides:
- `LLMChain` for composing multi-turn conversations with message history
- `LangChain.Function` for tool/function calling
- Streaming via `on_llm_new_delta` callbacks — natural fit for LiveView via `send/2` or PubSub
- `ChatAnthropic`, `ChatOpenAI`, `ChatGoogleAI` structs for provider selection
- Extended thinking blocks for Claude (v0.5+)

The `stream: true` option on the chat model struct enables streaming. In LiveView you send delta tokens to the LiveView pid inside the callback:

```elixir
handler = %{
  on_llm_new_delta: fn _chain, delta ->
    send(lv_pid, {:llm_delta, delta.content})
  end,
  on_message_processed: fn _chain, msg ->
    send(lv_pid, {:llm_done, msg})
  end
}

LLMChain.new!(%{
  llm: ChatAnthropic.new!(%{
    model: "claude-sonnet-4-5-20251001",
    stream: true
  })
})
|> LLMChain.add_callback(handler)
|> LLMChain.add_messages(messages)
|> LLMChain.run()
```

The LiveView's `handle_info/2` then appends tokens to a socket assign, producing the typewriter effect.

### InstructorLite (`instructor_lite` ~> 1.2)

- Hex.pm: https://hex.pm/packages/instructor_lite
- Latest: 1.2.0 (released February 1, 2026)
- Uses Req ~> 0.5 as default HTTP adapter (matches project dependency)
- Supports: OpenAI, Anthropic, Gemini, Grok, llama.cpp-compatible endpoints

InstructorLite coerces LLM output into Ecto schemas with automatic retry on validation failure. It does **not** support streaming. This makes it ideal for Insights generation and Vega-Lite spec creation, where you need deterministic, validated output — not for the chat interface.

```elixir
defmodule MetricFlow.Ai.VegaLiteSpec do
  use Ecto.Schema
  use InstructorLite.Instruction

  @doc "A Vega-Lite v5 visualization specification"
  @primary_key false
  embedded_schema do
    field :schema, :string
    field :mark, :string
    field :description, :string
    # nested encoding, data, etc. via embeds
  end
end

{:ok, spec} = InstructorLite.instruct(
  %{
    messages: [
      %{role: "user", content: prompt}
    ],
    model: "claude-sonnet-4-5-20251001"
  },
  response_model: MetricFlow.Ai.VegaLiteSpec,
  adapter: InstructorLite.Adapters.Anthropic,
  adapter_context: [api_key: System.fetch_env!("ANTHROPIC_API_KEY")]
)
```

### Raw Req (no library)

Building directly on `Req ~> 0.5` (already in the project) is possible but requires reimplementing: message history management, streaming SSE parsing, retry logic, and schema validation. This is significant undifferentiated work and should be avoided unless the libraries prove insufficient.

## Provider Options

See `providers.md` for detailed comparison. Summary:

| Provider | Best For | Context Window | Structured Output |
|---|---|---|---|
| Anthropic Claude Sonnet 4.5 | Chat + reasoning | 200K | Tool-use based; guaranteed via native structured outputs (beta) |
| OpenAI GPT-4o | Broad compatibility | 128K | Native JSON schema enforcement |
| Google Gemini 2.5 Flash | Cost efficiency, large datasets | 1M | Yes |

## Recommended Stack

- **Primary provider**: Anthropic Claude (Sonnet 4.5 for chat/insights, Haiku 4.5 for high-volume tasks)
- **LLM framework**: LangChain for Elixir (chat + conversational memory + tool calling)
- **Structured output**: InstructorLite (Vega-Lite spec generation, insights JSON)
- **HTTP client**: Req is used under the hood by both libraries — no extra client needed

See `docs/architecture/decisions/llm_provider.md` for the full decision record.
