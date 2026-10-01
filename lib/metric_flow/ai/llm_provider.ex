defmodule MetricFlow.Ai.LlmProvider do
  @moduledoc """
  Resolves the `Alloy` provider tuple used for AI tool-loop calls.

  The base provider is environment-specific, set in `config/runtime.exs`
  under `:metric_flow, :ai_chat_provider` (the Claude Code subscription CLI
  in dev and test, the real Anthropic Messages API in prod). Tests inject a
  `:command_runner` (see `MetricFlowTest.ClaudeCodeStub`) through
  `:command_runner` in opts — the same field name `Alloy.Provider.ClaudeCode`
  itself uses for this — so a scripted response replaces a real `claude` CLI
  invocation.
  """

  @doc """
  Returns the `{module, config}` tuple for `Alloy.run/2`'s `:provider` option.
  """
  @spec chat_provider(keyword()) :: {module(), keyword()}
  def chat_provider(opts \\ []) do
    {module, config} = Application.fetch_env!(:metric_flow, :ai_chat_provider)
    {module, merge_command_runner(module, config, opts[:command_runner])}
  end

  defp merge_command_runner(Alloy.Provider.ClaudeCode, config, runner) when is_function(runner, 3) do
    Keyword.put(config, :command_runner, runner)
  end

  defp merge_command_runner(_module, config, _runner), do: config
end
