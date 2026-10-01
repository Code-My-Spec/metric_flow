defmodule MetricFlow.Ai.VizTools.SearchDocs do
  @moduledoc "Alloy tool: full-text search across the Vega-Lite documentation corpus."

  @behaviour Alloy.Tool

  alias MetricFlow.Ai.VegaDocsReference

  @impl true
  def name, do: "search_docs"

  @impl true
  def description,
    do:
      "Search all Vega-Lite documentation for a keyword or phrase. Returns matching " <>
        "file paths and relevant lines. Use this to find the right doc page to read."

  @impl true
  def input_schema do
    %{
      type: "object",
      properties: %{
        query: %{
          type: "string",
          description: "Search term (e.g. 'named data source', 'temporal', 'color scale')"
        }
      },
      required: ["query"]
    }
  end

  @impl true
  def execute(%{"query" => query}, _context) do
    {:ok, VegaDocsReference.search(query)}
  end
end
