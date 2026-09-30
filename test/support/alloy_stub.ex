defmodule MetricFlowTest.AlloyStub do
  @moduledoc """
  Test-time `:command_runner` stub for Alloy.Provider.ClaudeCode.

  Claude Code normally shells out to a locally-authenticated `claude` CLI
  per call. `:command_runner` is the hook Alloy's own test suite uses to
  replace that subprocess with a plain function, so specs stay fast and
  deterministic without a real, logged-in CLI process. Mirrors the shape of
  Alloy's own `fake_runner/1`/`envelope/2` test helpers.

  Usage, once a call site is wired to `Alloy.Provider.ClaudeCode`:

      config = %{
        model: "claude-sonnet-5",
        command_runner:
          AlloyStub.fake_command_runner(fn _args, _opts ->
            AlloyStub.envelope(%{"stop_reason" => "end_turn", "text" => "canned reply", "tool_calls" => []})
          end)
      }
  """

  @doc """
  Wraps a 2-arity `(args, opts -> output)` function into the 3-arity shape
  `:command_runner` expects (matching `System.cmd/3`'s `(cmd, args, opts)`).

  `fun` may return a bare output string (status defaults to 0) or an
  `{output, status}` tuple.
  """
  @spec fake_command_runner((list(), keyword() -> String.t() | {String.t(), integer()})) ::
          (String.t(), list(), keyword() -> {String.t(), integer()})
  def fake_command_runner(fun) when is_function(fun, 2) do
    fn _cmd, args, opts ->
      case fun.(args, opts) do
        {output, status} when is_binary(output) and is_integer(status) -> {output, status}
        output when is_binary(output) -> {output, 0}
      end
    end
  end

  @doc """
  Builds the `--output-format json` result envelope Claude Code writes to
  stdout on success, wrapping the given `structured_output` (the decoded
  `{stop_reason, text, tool_calls}` payload).
  """
  @spec envelope(map(), keyword()) :: String.t()
  def envelope(structured_output, opts \\ []) do
    Jason.encode!(%{
      "type" => "result",
      "subtype" => Keyword.get(opts, :subtype, "success"),
      "is_error" => false,
      "result" => Jason.encode!(structured_output),
      "structured_output" => structured_output,
      "session_id" => Keyword.get(opts, :session_id, "sess_test"),
      "total_cost_usd" => Keyword.get(opts, :total_cost_usd, 0.001),
      "duration_ms" => Keyword.get(opts, :duration_ms, 100),
      "usage" => Keyword.get(opts, :usage, %{"input_tokens" => 5, "output_tokens" => 7})
    })
  end

  @doc """
  Convenience wrapper: a `command_runner` that always returns a plain
  end-turn reply with the given text and no tool calls.
  """
  @spec end_turn_command_runner(String.t()) :: (String.t(), list(), keyword() -> {String.t(), integer()})
  def end_turn_command_runner(text) do
    fake_command_runner(fn _args, _opts ->
      envelope(%{"stop_reason" => "end_turn", "text" => text, "tool_calls" => []})
    end)
  end
end
