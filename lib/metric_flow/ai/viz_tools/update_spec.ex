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

  Also checks that every named data source the spec references exists in
  `frame.assigns.metric_names` — the model can hallucinate a metric name
  that was never listed among the account's available metrics. On that
  failure, `frame.assigns.unresolvable_metrics` is set so the caller can
  surface the bad name directly instead of continuing the tool loop.
  """
  @impl true
  def execute(%{vega_lite_json: json}, frame) do
    metric_names = frame.assigns[:metric_names] || []

    with {:ok, spec} <- Jason.decode(json),
         {:ok, _spec} <- VegaSpecValidator.validate(spec),
         :ok <- validate_metric_names(spec, metric_names) do
      frame = put_in(frame.assigns[:validated_spec], spec)
      {:reply, Response.text(Response.tool(), "Spec updated successfully."), frame}
    else
      {:error, {:unresolvable_metrics, names}} ->
        frame = put_in(frame.assigns[:unresolvable_metrics], names)

        msg =
          "These metric names are not available in this account: " <> Enum.join(names, ", ")

        {:reply, Response.error(Response.tool(), msg), frame}

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

  # No known metrics to validate against (shouldn't normally happen — the
  # chat is only reachable once an account has metrics) — let it through
  # rather than reject every spec outright.
  defp validate_metric_names(_spec, []), do: :ok

  defp validate_metric_names(spec, metric_names) do
    referenced = extract_named_data_sources(spec)
    unresolvable = Enum.reject(referenced, &(&1 in metric_names))

    case unresolvable do
      [] -> :ok
      names -> {:error, {:unresolvable_metrics, names}}
    end
  end

  defp extract_named_data_sources(%{"data" => %{"name" => name}}) when is_binary(name),
    do: [name]

  defp extract_named_data_sources(%{"layer" => layers}) when is_list(layers) do
    Enum.flat_map(layers, &extract_named_data_sources/1)
  end

  defp extract_named_data_sources(_), do: []
end
