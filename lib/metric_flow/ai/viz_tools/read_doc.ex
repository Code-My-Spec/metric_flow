defmodule MetricFlow.Ai.VizTools.ReadDoc do
  @moduledoc "Alloy tool: read a single Vega-Lite documentation page by path."

  @behaviour Alloy.Tool

  alias MetricFlow.Ai.VegaDocsReference

  @impl true
  def name, do: "read_doc"

  @impl true
  def description,
    do: "Read a specific Vega-Lite documentation page. Returns the full markdown content."

  @impl true
  def input_schema do
    %{
      type: "object",
      properties: %{
        path: %{
          type: "string",
          description: "File path (e.g. 'data.md', 'mark/bar.md', 'encoding/scale.md')"
        }
      },
      required: ["path"]
    }
  end

  @impl true
  def execute(%{"path" => path}, _context) do
    {:ok, VegaDocsReference.read(path)}
  end
end
