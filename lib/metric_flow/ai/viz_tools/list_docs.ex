defmodule MetricFlow.Ai.VizTools.ListDocs do
  @moduledoc """
  Browse the Vega-Lite v5 documentation file tree. Returns directories and files
  at the given path. Start with an empty path to see the top level, then drill
  into subdirectories like 'mark', 'encoding', 'transform', etc.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MetricFlow.Ai.VegaDocsReference

  schema do
    field :path, :string,
      description: "Directory path (e.g. '' for root, 'mark', 'encoding')"
  end

  @impl true
  def execute(params, frame) do
    path = Map.get(params, :path, "")
    {:reply, Response.text(Response.tool(), VegaDocsReference.list(path)), frame}
  end
end
