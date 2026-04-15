# Model Selection Patterns

## Provider:Model String Format

ReqLLM uses a `"provider:model-name"` string to identify the model for all API calls. This
format is consistent across `generate_text/3`, `stream_text/3`, `generate_object/4`, and
embedding functions. Switching providers requires changing only this string.

```elixir
# Anthropic Claude
"anthropic:claude-sonnet-4-5"
"anthropic:claude-haiku-4-5"

# Hypothetical future switch to OpenAI — no other code changes required
"openai:gpt-5"
"openai:gpt-5-mini"

# Google Gemini — same pattern
"google:gemini-2.5-flash"
```

## MetricFlow Model Assignments

Two models are used across the three `MetricFlow.Ai` features:

| Feature | Model | Rationale |
|---|---|---|
| AI Chat (streaming) | `anthropic:claude-sonnet-4-5` | User-facing; quality matters more than cost |
| Vega-Lite Report Generation | `anthropic:claude-sonnet-4-5` | Complex schema; better at spec compliance |
| AI Insights (batch, Oban) | `anthropic:claude-haiku-4-5` | Not user-visible; cost efficiency priority |

Define these as module-level constants in `MetricFlow.Ai.LlmClient`. Never scatter model
strings across feature modules — changes should require editing exactly one file.

```elixir
defmodule MetricFlow.Ai.LlmClient do
  @chat_model     "anthropic:claude-sonnet-4-5"
  @insights_model "anthropic:claude-haiku-4-5"

  def chat_model,     do: @chat_model
  def insights_model, do: @insights_model
end
```

## Anthropic Claude Pricing (as of February 2026)

| Model | Input per M tokens | Output per M tokens | Context Window |
|---|---|---|---|
| Claude Opus 4.1 | $15.00 | $75.00 | 200K |
| Claude Sonnet 4.5 | $3.00 | $15.00 | 200K |
| Claude Haiku 4.5 | $1.00 | $5.00 | 200K |

All Anthropic models support:
- 200K token context window (MetricFlow's 45–50K prompt fits comfortably)
- Native Structured Outputs (public beta, Sonnet 4.5 and above)
- Prompt caching (0.1x read cost after 5-minute window)
- Tool use / function calling

## Cost Estimate for MetricFlow

Assume 100 active accounts, 10 AI chat interactions per day, 50K tokens per request (system
prompt + metrics data + conversation history), 1.5K tokens output:

```
Chat (claude-sonnet-4-5):
  Input:  100 accounts × 10 req × 50K tokens × $3.00/M  = $150/day
  Output: 100 accounts × 10 req × 1.5K tokens × $15.00/M = $22.50/day
  Total: ~$172.50/day (~$5,175/month)

With prompt caching on 5K-token system prompt (90% of system prompt cost reduced):
  Effective cost reduction: ~$13/day on cached tokens
  Total with caching: ~$159/day

Insights batch (claude-haiku-4-5):
  Assume 1 insight per account per day, 15K tokens input, 500 tokens output:
  Input:  100 × 15K × $1.00/M = $1.50/day
  Output: 100 × 500 × $5.00/M = $0.25/day
  Total: ~$1.75/day (negligible)
```

Prompt caching provides meaningful savings at scale. Implement for the static system prompt
and shared metrics context block (see streaming.md).

## When to Upgrade or Downgrade Models

Upgrade to `claude-sonnet-4-5` for Insights if:
- Users report that generated insights are too generic or miss key correlations
- Haiku fails to produce valid structured output reliably

Downgrade Chat to `claude-haiku-4-5` if:
- Cost monitoring shows API spend exceeds budget at current scale
- Chat response quality is acceptable on Haiku for most queries

Evaluate on logged token usage and qualitative feedback — do not change models without data.

## Extended Thinking (Future)

Anthropic's extended thinking mode is available on Claude Sonnet 4.5+ for complex reasoning
tasks. This is relevant for the correlation engine's most complex multi-platform attribution
questions. ReqLLM passes provider-specific options through to the API; enable thinking via:

```elixir
ReqLLM.generate_text(
  "anthropic:claude-sonnet-4-5",
  messages,
  thinking: %{type: "enabled", budget_tokens: 5000}
)
```

Do not enable thinking for standard chat or insights generation — it increases latency and cost
significantly. Reserve it for a future "deep analysis" mode if users request it.
