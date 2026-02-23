# LLM Provider Comparison

## Anthropic Claude

### Models and Pricing (as of February 2026)

| Model | Input $/M | Output $/M | Context Window | Notes |
|---|---|---|---|---|
| Claude Opus 4.1 | $15.00 | $75.00 | 200K | Highest capability |
| Claude Sonnet 4.5 | $3.00 | $15.00 | 200K | Best balance for MetricFlow |
| Claude Haiku 4.5 | $1.00 | $5.00 | 200K | Fastest, cheapest |
| Claude Haiku 3.5 | $0.80 | $4.00 | 200K | Older generation |

Prompt caching: cache read = 0.1x input price, 5-min cache write = 1.25x, 1-hour = 2x. For repeated system prompts (e.g., metric schema context), caching provides significant cost reduction.

### Structured Output

Anthropic released native Structured Outputs in public beta (November 2025) for Sonnet 4.5 and Opus 4.1. This guarantees JSON schema compliance on the first try. Prior to this, Claude used tool-call based JSON extraction, which worked well but was more verbose to configure.

InstructorLite's Anthropic adapter uses the tool-call approach for all models and adds Ecto-validated retries on top.

### Tool Use / Function Calling

Claude has first-class tool use support. You can force a specific tool to be used via `tool_choice`. This is the mechanism LangChain for Elixir uses for structured outputs when working with Claude.

### Streaming

SSE-based streaming is supported. LangChain's `ChatAnthropic` struct fires `on_llm_new_delta` callbacks with each token.

### Strengths for MetricFlow

- 200K context window comfortably holds a month of daily metrics for multiple platforms (GA4, Google Ads, Facebook Ads, QuickBooks) inline in the prompt
- Excellent at following JSON schemas for Vega-Lite spec generation
- Extended thinking (claude-3-7-sonnet) available for complex correlation reasoning
- `MetricFlow.Ai` context will likely need nuanced data analysis — Claude is strong here

---

## OpenAI GPT

### Models and Pricing (as of February 2026)

| Model | Input $/M | Output $/M | Context Window | Notes |
|---|---|---|---|---|
| GPT-5 | $1.25 | $10.00 | 128K | New flagship |
| GPT-5 Mini | $0.25 | $2.00 | 128K | Cost-effective |
| GPT-4o | $5.00 | $20.00 | 128K | Previous flagship |
| GPT-4o Mini | $0.60 | $2.40 | 32K | Budget option |

### Structured Output

OpenAI's Structured Outputs feature (`response_format: {type: "json_schema", ...}`) is available on GPT-4o and GPT-5, and enforces strict JSON schema adherence. This was the first major provider to ship guaranteed schema compliance, and is well-tested in production.

InstructorLite's OpenAI adapter works directly with this feature.

### Streaming

Full SSE streaming, supported via LangChain `ChatOpenAI` struct.

### Considerations for MetricFlow

- Smaller context window (128K) than Claude. For a single account with ~90 days of daily multi-platform metrics, 128K is likely sufficient, but less headroom.
- GPT-5 at $1.25/$10 per million is competitive with Claude Sonnet 4.5 at $3/$15.
- Mature ecosystem, most documentation examples use OpenAI.
- LangChain for Elixir's `ChatOpenAI` is the most battle-tested integration.

---

## Google Gemini

### Models and Pricing (as of February 2026)

| Model | Input $/M | Output $/M | Context Window | Notes |
|---|---|---|---|---|
| Gemini 2.5 Pro | $1.25–$2.50 | $10–$15 | 1M | Tiered above 200K |
| Gemini 2.5 Flash | $0.15 | $0.60–$3.50 | 1M | Cheapest option |

### Structured Output

Gemini supports JSON output mode and structured generation, supported by InstructorLite's Gemini adapter.

### Streaming

Supported via LangChain `ChatGoogleAI`.

### Considerations for MetricFlow

- 1M token context window is exceptional — could embed years of raw metrics without retrieval
- Gemini 2.5 Flash at $0.15/$0.60 per million is extremely cheap for non-reasoning tasks
- Less community testing in the Elixir ecosystem; LangChain's `ChatGoogleAI` integration is newer
- MetricFlow already has a Google OAuth integration (Google Analytics, Google Ads) — same GCP project could be used for Gemini API, simplifying billing
- However, analysis quality for complex marketing analytics reasoning is less proven than Claude

---

## Provider Decision Factors

### Context Window vs. Token Cost

For MetricFlow's "chat about metrics" use case, the prompt will contain:
- System prompt with schema and instructions (~2K tokens)
- Conversation history (~2K per turn, say 10 turns = 20K)
- Injected metrics data (90 days, 4 platforms, ~500 rows = ~15–25K tokens)

Total: roughly 40–50K tokens per request in steady state. All three providers handle this comfortably. Gemini's 1M context only becomes meaningful if you wanted to embed full historical data going back years.

### Cost Estimate at Scale

Assume 100 active accounts, each with 10 AI interactions per day, 50K tokens per request:
- 100 accounts x 10 requests x 50K input + 2K output = ~52M tokens/day
- Claude Sonnet 4.5: ~$156/day (~$4.7K/month)
- Claude Haiku 4.5: ~$52/day (~$1.6K/month)
- GPT-5: ~$85/day (~$2.6K/month)
- Gemini 2.5 Flash: ~$8/day (~$240/month)

For a startup, Claude Haiku 4.5 or Gemini Flash for high-volume tasks (insights batch generation) and Claude Sonnet 4.5 for the interactive chat would be a sensible tiered approach.

### Elixir Library Compatibility

All three providers are supported by both LangChain for Elixir and InstructorLite. The project already uses `assent` for OAuth and `req ~> 0.5` for HTTP — InstructorLite's optional Req adapter aligns naturally.
