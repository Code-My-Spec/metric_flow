# ReqLLM Setup and Configuration

This file covers dependency installation, API key configuration, and the `MetricFlow.Ai.LlmClient`
wrapper module that all three AI features will go through.

## Dependency

Add `req_llm` to `mix.exs`. ReqLLM is built on Finch (compatible with Req's HTTP stack) and does
not introduce a Tesla or Hackney dependency. As of February 2026 the latest stable release is
`~> 1.6`.

```elixir
# mix.exs — deps/0
{:req_llm, "~> 1.6"},
{:req_cassette, "~> 0.5", only: :test}  # For test recording; see testing.md
```

The project's existing `{:req, "~> 0.5"}` dependency is unaffected — ReqLLM uses Finch
internally and sits alongside Req rather than replacing it.

## API Key Configuration

ReqLLM resolves API keys from multiple sources in this order:

1. Per-request `:api_key` option (highest priority)
2. In-memory storage via `ReqLLM.Keys`
3. Application config (`:req_llm` OTP app)
4. `ANTHROPIC_API_KEY` environment variable
5. `.env` file in the project root (loaded at startup)

For MetricFlow, use application config sourced from environment variables. This matches the
pattern already used by `MetricFlow.Infrastructure.Vault` and the OAuth provider config.

### config/runtime.exs

Add within the `if config_env() == :prod` block alongside the existing database config:

```elixir
# config/runtime.exs
config :req_llm,
  anthropic_api_key: System.get_env("ANTHROPIC_API_KEY") ||
    raise("environment variable ANTHROPIC_API_KEY is missing.")
```

For non-production environments the key is resolved from the environment variable automatically
without raising. During local development, add `ANTHROPIC_API_KEY` to your `.env` file — ReqLLM
loads `.env` from the project root at startup.

### config/test.exs

In tests, ReqCassette intercepts HTTP calls before they reach Anthropic. No real API key is
needed. To make the absence of a key explicit rather than silently falling through:

```elixir
# config/test.exs
config :req_llm, anthropic_api_key: "test-key-not-used"
```

## Model Selection

The project decision uses two Anthropic models. Reference these strings as named constants
rather than scattering string literals:

```elixir
# lib/metric_flow/ai/llm_client.ex
defmodule MetricFlow.Ai.LlmClient do
  @moduledoc """
  Thin wrapper around ReqLLM standardising model selection, system prompts,
  and error handling for the three MetricFlow.Ai use cases.

  Model selection:
  - @chat_model    — Interactive chat and Vega-Lite report generation
  - @insights_model — Batch insights generation (cost-efficient)
  """

  # Best quality/cost balance; 200K context window; used for user-facing chat
  # and report generation where output quality matters most.
  @chat_model "anthropic:claude-sonnet-4-5"

  # Cost-efficient tier; same 200K context; used for Oban batch insight jobs
  # where latency is not user-visible.
  @insights_model "anthropic:claude-haiku-4-5"

  def chat_model, do: @chat_model
  def insights_model, do: @insights_model
end
```

### Why These Models

| Model | Price (in/out per M tokens) | Use in MetricFlow |
|---|---|---|
| `anthropic:claude-sonnet-4-5` | $3.00 / $15.00 | Chat, Vega-Lite report generation |
| `anthropic:claude-haiku-4-5` | $1.00 / $5.00 | Batch insights generation via Oban |

Switching to OpenAI or Gemini requires only changing the model string — no code changes to
`stream_text/3` or `generate_object/4` call sites.

## System Prompt Pattern

All three AI features share a common system prompt foundation. Centralise this in `LlmClient`:

```elixir
defmodule MetricFlow.Ai.LlmClient do
  @base_system_prompt """
  You are a marketing analytics assistant for MetricFlow. You help users understand
  their performance data across Google Analytics, Google Ads, Facebook Ads, and QuickBooks.

  When analysing data:
  - Reference specific numbers from the provided metrics
  - Flag correlations between platforms when relevant
  - Express confidence levels where appropriate
  - Use clear, non-technical language unless the user asks otherwise
  """

  def base_system_prompt, do: @base_system_prompt
end
```

Feature modules (e.g., `InsightsGenerator`, `ReportGenerator`) append their own task-specific
instructions to `base_system_prompt()` rather than building prompts from scratch.

## Boundary Configuration

`MetricFlow.Ai` will need its own Boundary declaration. Add to the context module when it is
created:

```elixir
defmodule MetricFlow.Ai do
  use Boundary,
    deps: [MetricFlow.Users, MetricFlow.Infrastructure, MetricFlow.Metrics],
    exports: [ChatSession, InsightResult, VegaLiteSpec]
end
```

ReqLLM itself does not need to be listed in `deps` — it is a library dependency, not a Boundary
module.

## Oban Queue for Batch AI

Insights generation runs in background jobs. Add an `:ai` queue alongside the existing queues:

```elixir
# config/config.exs
config :metric_flow, Oban,
  repo: MetricFlow.Infrastructure.Repo,
  queues: [default: 10, sync: 5, ai: 3]
```

The `ai` queue concurrency of 3 limits parallel Anthropic API calls in the development
environment; raise this in production based on rate limits and cost budget.

## Verifying Setup

After adding the dependency and config, confirm ReqLLM resolves the key correctly:

```elixir
# In iex -S mix
ReqLLM.generate_text("anthropic:claude-haiku-4-5", "Reply with the word READY")
# {:ok, %ReqLLM.Response{...}}
```

A successful response confirms the API key is resolved and the Finch connection pool is active.
