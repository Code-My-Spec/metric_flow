defmodule MetricFlow.Ai.LlmTools.EmitVegaSpec do
  @moduledoc """
  Alloy forced tool: report a generated Vega-Lite v5 specification as
  structured data.

  Used with `until_tool: "emit_vega_spec"` so `Alloy.run/2`'s loop does not
  end until the model calls this, which is how `LlmClient.generate_vega_spec/3`
  gets its structured result instead of free-form text.
  """

  @behaviour Alloy.Tool

  @impl true
  def name, do: "emit_vega_spec"

  @impl true
  def description, do: "Report the generated Vega-Lite v5 chart specification."

  @impl true
  def input_schema do
    %{
      "type" => "object",
      "properties" => %{"spec" => %{"type" => "object"}},
      "required" => ["spec"]
    }
  end

  @impl true
  def execute(%{"spec" => spec} = input, _context) when is_map(spec) do
    {:ok, "Spec recorded.", input}
  end

  @impl true
  def result_type, do: :structured
end
