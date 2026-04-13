defmodule MetricFlow.Ai.VizTools.SearchDocs do
  @moduledoc """
  Search all Vega-Lite documentation for a keyword or phrase. Returns matching
  file paths and relevant lines. Use this to find the right doc page to read.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MetricFlow.Ai.VegaDocsReference

  schema do
    field :query, :string,
      required: true,
      description:
        "Search term (e.g. 'named data source', 'temporal', 'color scale')"
  end

  @impl true
  def execute(%{query: query}, frame) do
    {:reply, Response.text(Response.tool(), VegaDocsReference.search(query)), frame}
  end
end
