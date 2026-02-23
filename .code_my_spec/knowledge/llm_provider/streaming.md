# Streaming Text to LiveView with ReqLLM

This file covers the `stream_text/3` API and the pattern for delivering tokens to a Phoenix
LiveView in real time.

## How ReqLLM Streaming Works

`ReqLLM.stream_text/3` returns a `StreamResponse` struct immediately. The struct wraps:

- A **lazy token stream** — an Enumerable of string tokens, consumed as they arrive
- A **metadata handle** — resolved concurrently; contains usage counts and finish reason
- A **cancel function** — terminates the stream and cleans up resources

This design means token delivery does not block on collecting usage data. The two can proceed
in parallel.

```elixir
{:ok, response} = ReqLLM.stream_text("anthropic:claude-sonnet-4-5", messages)

# Lazy stream of string tokens — pull one at a time
stream = ReqLLM.StreamResponse.tokens(response)

# Blocking call — waits until the stream finishes, then returns usage
usage = ReqLLM.StreamResponse.usage(response)
# %{input_tokens: 1200, output_tokens: 340, cost_usd: 0.0087}
```

## LiveView Streaming Pattern

The canonical pattern for MetricFlow chat:

1. The LiveView receives a "send message" event.
2. It spawns a `Task` to run the stream (streaming blocks the calling process).
3. The Task sends `{:chat_token, token}` messages to the LiveView pid as tokens arrive.
4. When the stream finishes, the Task sends `{:chat_complete, usage}` with token counts.
5. `handle_info/2` in the LiveView appends tokens to a socket assign and updates the UI.

```elixir
defmodule MetricFlowWeb.ChatLive do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Ai.LlmClient

  def handle_event("send_message", %{"message" => text}, socket) do
    lv_pid = self()
    messages = LlmClient.build_chat_messages(socket.assigns.chat_session, text)

    Task.start(fn ->
      case ReqLLM.stream_text(LlmClient.chat_model(), messages) do
        {:ok, response} ->
          response
          |> ReqLLM.StreamResponse.tokens()
          |> Stream.each(fn token -> send(lv_pid, {:chat_token, token}) end)
          |> Stream.run()

          usage = ReqLLM.StreamResponse.usage(response)
          send(lv_pid, {:chat_complete, usage})

        {:error, reason} ->
          send(lv_pid, {:chat_error, reason})
      end
    end)

    {:noreply,
     socket
     |> assign(:streaming, true)
     |> assign(:current_response, "")}
  end

  def handle_info({:chat_token, token}, socket) do
    updated = socket.assigns.current_response <> token
    {:noreply, assign(socket, :current_response, updated)}
  end

  def handle_info({:chat_complete, usage}, socket) do
    # Persist the completed message; log usage for cost monitoring
    :telemetry.execute([:metric_flow, :ai, :chat_complete], usage, %{})

    {:noreply,
     socket
     |> assign(:streaming, false)
     |> push_event("chat_complete", %{})}
  end

  def handle_info({:chat_error, reason}, socket) do
    {:noreply,
     socket
     |> assign(:streaming, false)
     |> put_flash(:error, "AI response failed: #{inspect(reason)}")}
  end
end
```

## System Prompt in stream_text

Pass messages as a list of maps. Include the system prompt as the first message with
`role: "system"`:

```elixir
defmodule MetricFlow.Ai.LlmClient do
  def build_chat_messages(chat_session, new_user_text) do
    system = %{
      role: "system",
      content: base_system_prompt() <> metrics_context(chat_session)
    }

    history = Enum.map(chat_session.messages, fn msg ->
      %{role: msg.role, content: msg.content}
    end)

    user = %{role: "user", content: new_user_text}

    [system | history] ++ [user]
  end

  defp metrics_context(chat_session) do
    """

    ## Available Metrics

    #{Jason.encode!(chat_session.metrics_snapshot, pretty: true)}
    """
  end
end
```

## Options for stream_text

```elixir
ReqLLM.stream_text(model, messages,
  max_tokens: 2048,          # default varies by provider
  temperature: 0.7,          # 0.0–1.0; lower = more deterministic
  api_key: "override-key"    # per-request key override if needed
)
```

## Cancelling a Stream

If the user navigates away or starts a new message mid-stream, cancel the in-progress response
to avoid orphaned API costs:

```elixir
# Store the cancel function in the socket
{:ok, response} = ReqLLM.stream_text(model, messages)
cancel_fn = ReqLLM.StreamResponse.cancel(response)

# Call it when the LiveView terminates or the user interrupts
cancel_fn.()
```

In practice for MetricFlow MVP, the `Task` will simply run to completion and the final tokens
will be discarded. Implement cancel if cost monitoring shows meaningful waste from abandoned
streams.

## Token Usage Telemetry

Log token counts after each chat response. This surfaces in Phoenix LiveDashboard and enables
cost tracking:

```elixir
def handle_info({:chat_complete, usage}, socket) do
  :telemetry.execute(
    [:metric_flow, :ai, :tokens],
    %{input: usage.input_tokens, output: usage.output_tokens},
    %{model: LlmClient.chat_model(), feature: :chat}
  )
  # ...
end
```

## Prompt Caching (Cost Optimisation)

Anthropic's prompt caching bills repeated system prompts at 0.1x the input token rate after
the first request. For a 5K-token system prompt shared across a 10-turn chat session, this
saves ~90% of system-prompt costs.

ReqLLM passes through Anthropic's `cache_control` parameter in message content blocks. When
the feature is built, wrap the static system prompt and metrics context with cache markers.
Refer to the Anthropic documentation for the exact message structure — this is a future
optimisation, not an MVP requirement.
