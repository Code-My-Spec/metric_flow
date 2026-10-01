defmodule MetricFlow.Ai.VizChat.UnresolvableMetricHalt do
  @moduledoc """
  Stops the agent loop immediately when `update_spec` reports a metric name
  that doesn't exist for this account, rather than letting the model keep
  guessing at a name that will never resolve.

  `UpdateSpec` encodes this failure as an `{:error, reason}` tool result
  whose text starts with a fixed prefix (`unresolvable_prefix/0`). Alloy
  records that string verbatim on the tool-call entry it appends to
  `state.tool_calls`, so this middleware only has to look for it there.
  """

  @behaviour Alloy.Middleware

  alias MetricFlow.Ai.VizTools.UpdateSpec

  @impl true
  def call(:after_tool_execution, state) do
    case find_unresolvable_error(state.tool_calls) do
      nil -> state
      reason -> {:halt, reason}
    end
  end

  def call(_hook, state), do: state

  defp find_unresolvable_error(tool_calls) do
    prefix = UpdateSpec.unresolvable_prefix()

    Enum.find_value(tool_calls, fn
      %{error: error} when is_binary(error) ->
        if String.starts_with?(error, prefix), do: error

      _ ->
        nil
    end)
  end
end
