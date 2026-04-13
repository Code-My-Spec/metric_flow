defmodule MetricFlow.Ai.VizTools.UpdateSpec do
  @moduledoc """
  Update the Vega-Lite visualization specification. Call this whenever the user
  asks you to create, modify, or refine a chart. Pass the complete Vega-Lite v5
  spec as a JSON string. Use named data sources ("data": {"name": "metricName"})
  instead of embedding data values.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias MetricFlow.Ai.VegaSpecValidator

  schema do
    field :vega_lite_json, :string,
      required: true,
      description: "Complete Vega-Lite v5 JSON spec as a string"
  end

  @doc """
  Validates and parses the Vega-Lite spec. On success, stores the parsed
  spec in `frame.assigns.validated_spec` so the agent loop can capture it
  without re-parsing.
  """
  @impl true
  def execute(%{vega_lite_json: json}, frame) do
    with {:ok, spec} <- Jason.decode(json),
         {:ok, _spec} <- VegaSpecValidator.validate(spec) do
      frame = put_in(frame.assigns[:validated_spec], spec)
      {:reply, Response.text(Response.tool(), "Spec updated successfully."), frame}
    else
      {:error, errors} when is_list(errors) ->
        msg =
          "Spec failed Vega-Lite schema validation. Fix these errors and try again:\n" <>
            Enum.join(errors, "\n")

        {:reply, Response.error(Response.tool(), msg), frame}

      {:error, _} ->
        {:reply,
         Response.error(
           Response.tool(),
           "Invalid JSON in vega_lite_json. Check syntax and try again."
         ), frame}
    end
  end
end
