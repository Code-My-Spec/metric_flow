defmodule MetricFlow.Ai.VizTools.ListDocs do
  @moduledoc "Alloy tool: browse the Vega-Lite documentation file tree."

  @behaviour Alloy.Tool

  alias MetricFlow.Ai.VegaDocsReference

  @impl true
  def name, do: "list_docs"

  @impl true
  def description,
    do:
      "Browse the Vega-Lite v5 documentation file tree. Returns directories and files " <>
        "at the given path. Start with an empty path to see the top level, then drill " <>
        "into subdirectories like 'mark', 'encoding', 'transform', etc."

  @impl true
  def input_schema do
    %{
      type: "object",
      properties: %{
        path: %{type: "string", description: "Directory path (e.g. '' for root, 'mark', 'encoding')"}
      }
    }
  end

  @impl true
  def execute(input, _context) do
    path = Map.get(input, "path", "")
    {:ok, VegaDocsReference.list(path)}
  end
end
