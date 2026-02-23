# Passing Metrics Data to LLMs

## Context Window Requirements

MetricFlow's chat and insights features need to pass time-series metrics data to the LLM. Understanding token requirements helps choose the right strategy and model.

### Token Estimates for Metrics Data

A single row of daily metrics for one platform might look like:
```
{"date":"2025-01-15","platform":"google_analytics","sessions":1423,"pageviews":3820,"bounce_rate":0.52}
```
This is roughly 90–100 tokens per row when JSON-encoded.

| Dataset | Rows | Estimated Tokens |
|---|---|---|
| 30 days, 1 platform | 30 | ~3K |
| 90 days, 1 platform | 90 | ~9K |
| 90 days, 4 platforms | 360 | ~36K |
| 365 days, 4 platforms | 1,460 | ~146K |

For the typical MetricFlow use case (90 days, 4 platforms), 36K tokens for data plus 5–10K for system prompt and conversation history puts total prompt size at ~45–50K tokens — well within Claude Sonnet's 200K window with substantial headroom.

## Strategy: Embed vs. Tool-Call Retrieval

Two approaches for getting data into LLM context:

### Option A: Embed Data in Prompt (Recommended for MVP)

Pre-query the relevant metrics and include them directly in the system prompt or first user message. Simpler to implement, lower latency (no round trips for tool calls).

```elixir
defmodule MetricFlow.Ai.ContextBuilder do
  def build_metrics_context(scope, date_range) do
    metrics = MetricFlow.Metrics.list_for_ai(scope, date_range)

    """
    ## Available Metrics Data

    The following data is available for analysis:

    #{Jason.encode!(metrics, pretty: true)}

    Data covers #{date_range.start} to #{date_range.end}.
    All monetary values are in USD.
    """
  end
end
```

Suitable for: conversational chat where the user has selected a specific time range, Insights generation for a fixed analysis period.

### Option B: Tool-Call Retrieval

Define LangChain `Function` tools that the LLM calls to fetch specific data. The LLM reasons about what it needs, calls the tool, receives the data, then continues.

```elixir
Function.new!(%{
  name: "query_metrics",
  description: "Query time-series metrics data",
  parameters_schema: %{
    type: "object",
    properties: %{
      platform: %{type: "string"},
      metrics: %{type: "array", items: %{type: "string"}},
      start_date: %{type: "string"},
      end_date: %{type: "string"},
      granularity: %{type: "string", enum: ["daily", "weekly", "monthly"]}
    },
    required: ["platform", "metrics", "start_date", "end_date"]
  },
  function: &MetricFlow.Ai.DataTools.query_metrics/2
})
```

Advantages: LLM only fetches what it needs; works better for open-ended exploration. Disadvantages: 1–3 extra round trips add 2–5 seconds of latency; more complex to implement.

**Recommendation**: Start with Option A (embedded data) for MVP. Adopt tool-call retrieval if users ask questions that span date ranges not covered by the initial context, or if prompt costs become a concern.

## Prompt Caching

Anthropic's prompt caching can dramatically reduce costs for repeated system prompts. The MetricFlow system prompt (schema description, instructions, metric definitions) can be cached:

- Cache write is billed at 1.25x input token price, once per 5 minutes
- Cache reads are billed at 0.1x input token price
- For a chat session with 10 turns sharing the same 5K-token system prompt, caching saves ~90% of system-prompt costs

LangChain for Elixir v0.5 supports Anthropic's `cache_control` parameter in messages. Wrap the system prompt and static metrics context with cache control markers.

## Data Formatting Tips

The LLM understands structured data better when formatted clearly:

- Use JSON for machine-processed outputs (Insights, Vega-Lite specs)
- Use Markdown tables or CSV for human-readable data discussions in chat
- Label columns with units: `sessions`, `revenue_usd`, `ctr_percent`
- Include metadata: date range, data source, any gaps or anomalies flagged
- Normalize missing values explicitly: `null` or `"N/A"` rather than omitting rows

## Conversation Memory for Chat Sessions

The `ChatSession` module will need to persist and reload message history. Considerations:

- Store messages in the database as `MetricFlow.Ai.ChatMessage` records
- On session load, hydrate `LLMChain` with stored messages via `LLMChain.add_messages/2`
- Implement a sliding window or summarisation to manage context growth in long sessions
- Claude's 200K context window means truncation is rarely needed in practice for sessions under ~100 turns
