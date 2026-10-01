defmodule MetricFlowTest.ClaudeCodeStub do
  @moduledoc """
  Builds a `:command_runner` stub for `Alloy.Provider.ClaudeCode`, so BDD
  specs and exunit tests never shell out to a real `claude` CLI process.

  `Alloy.Provider.ClaudeCode` scans its subprocess's stdout backward for the
  last line decoding to `%{"type" => "result"}` (see
  `claude_error/3`/`parse_envelope/1` in
  `deps/alloy/lib/alloy/provider/claude_code.ex`), so a stub only needs to
  produce that one JSON line, not the full `stream-json` transcript a real
  `claude -p --output-format stream-json` run would emit.

  Each test names its scripted response with `text/1` or `tool_call/2,3`;
  `sequence/1` chains several for a multi-turn conversation.
  """

  @type runner :: (String.t(), [String.t()], keyword() -> {String.t(), integer()})

  @doc "A command_runner returning a plain end_turn text reply."
  @spec text(String.t()) :: runner()
  def text(reply_text) do
    constant(%{"stop_reason" => "end_turn", "text" => reply_text, "tool_calls" => []})
  end

  @doc "A command_runner that calls one tool. `:text` is optional accompanying commentary."
  @spec tool_call(String.t(), map(), keyword()) :: runner()
  def tool_call(name, arguments, opts \\ []) do
    call_id = Keyword.get(opts, :call_id, "call_1")
    text = Keyword.get(opts, :text, "")

    constant(%{
      "stop_reason" => "tool_use",
      "text" => text,
      "tool_calls" => [%{"call_id" => call_id, "name" => name, "arguments" => arguments}]
    })
  end

  @doc """
  A `tool_call/3` immediately followed by a `text/1` end_turn reply.

  `Alloy.Agent.Turn` always calls the provider again after executing a tool
  (there is no "stop after one tool call" mode), so a single `tool_call/3`
  inside a `sequence/1` is not one conversational turn — the loop consumes
  further scripted responses from the same sequence trying to reach
  `:end_turn` on its own. Use this instead of a bare `tool_call/3` for any
  response meant to sit inside a `sequence/1`.
  """
  @spec completed_tool_call(String.t(), map(), keyword()) :: [runner()]
  def completed_tool_call(name, arguments, opts \\ []) do
    {completion_text, opts} = Keyword.pop(opts, :completion_text, "Done.")
    [tool_call(name, arguments, opts), text(completion_text)]
  end

  @doc """
  A command_runner stepping through one scripted response per call, for a
  multi-turn conversation where each turn needs a different reply. Each
  element is a runner built with `text/1` or `tool_call/2,3`, or a list of
  runners (e.g. from `completed_tool_call/3`) — lists are flattened.
  """
  @spec sequence([runner() | [runner()]]) :: runner()
  def sequence(runners) do
    {:ok, agent} = Agent.start_link(fn -> List.flatten(runners) end)

    fn exe, args, opts ->
      next =
        Agent.get_and_update(agent, fn
          [runner | rest] -> {runner, rest}
          [] -> raise "ClaudeCodeStub.sequence/1 exhausted: no more scripted responses"
        end)

      next.(exe, args, opts)
    end
  end

  @doc "A command_runner simulating a failed Claude Code CLI invocation."
  @spec error(String.t(), integer()) :: runner()
  def error(message, status \\ 1) do
    envelope = Jason.encode!(%{"type" => "result", "is_error" => true, "result" => message})
    fn _exe, _args, _opts -> {envelope, status} end
  end

  defp constant(structured_output) do
    envelope =
      Jason.encode!(%{
        "type" => "result",
        "is_error" => false,
        "structured_output" => structured_output
      })

    fn _exe, _args, _opts -> {envelope, 0} end
  end
end
