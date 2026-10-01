defmodule MetricFlow.Ai.LlmProvider do
  @moduledoc """
  Resolves the `Alloy` provider tuple used for AI tool-loop calls.

  The base provider is environment-specific, set in `config/runtime.exs`
  under `:metric_flow, :ai_chat_provider` (Claude Code CLI in dev, the real
  Anthropic Messages API in test and prod). Callers pass `req_http_options:`
  the same way they already do for ReqLLM — this merges it into the
  Anthropic provider's `:req_options`, which Alloy forwards straight to
  `Req.request/1`, so existing ReqCassette plug stubs intercept these calls
  exactly as they did before.
  """

  @doc """
  Returns the `{module, config}` tuple for `Alloy.run/2`'s `:provider` option.
  """
  @spec chat_provider(keyword()) :: {module(), keyword()}
  def chat_provider(opts \\ []) do
    {module, config} = Application.fetch_env!(:metric_flow, :ai_chat_provider)
    {module, merge_req_options(module, config, opts[:req_http_options])}
  end

  defp merge_req_options(Alloy.Provider.Anthropic, config, req_options) when is_list(req_options) do
    Keyword.put(config, :req_options, req_options)
  end

  defp merge_req_options(_module, config, _req_options), do: config
end
