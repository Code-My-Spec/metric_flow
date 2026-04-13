defmodule MetricFlow.Ai.VizTools.ReadDoc do
  @moduledoc """
  Read a specific Vega-Lite documentation page. Returns the full markdown content.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MetricFlow.Ai.VegaDocsReference

  schema do
    field :path, :string,
      required: true,
      description:
        "File path (e.g. 'data.md', 'mark/bar.md', 'encoding/scale.md')"
  end

  @impl true
  def execute(%{path: path}, frame) do
    {:reply, Response.text(Response.tool(), VegaDocsReference.read(path)), frame}
  end
end
