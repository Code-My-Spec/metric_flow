defmodule MetricFlow.Ai.VizTools.UpdateSpec do
  @moduledoc """
  Validates and parses the Vega-Lite spec the model proposes.

  On success, returns the parsed spec as structured data (`%{spec: spec}`) so
  `VizChat` can pull it out of `Alloy.Result.tool_calls` without re-parsing.

  Checks that every named data source the spec references exists in the
  account's available metrics (`context[:metric_names]`) — the model can
  hallucinate a metric name that was never listed. On that failure, the error
  text carries a fixed `unresolvable_metric:` prefix so
  `MetricFlow.Ai.VizChat.UnresolvableMetricHalt` can recognize it and stop the
  agent loop immediately rather than let the model keep guessing.
  """

  @behaviour Alloy.Tool

  alias MetricFlow.Ai.VegaSpecValidator

  @unresolvable_prefix "unresolvable_metric:"

  @impl true
  def name, do: "update_spec"

  @impl true
  def description,
    do: "Update the Vega-Lite v5 chart specification. Pass the COMPLETE spec as a JSON string."

  @impl true
  def input_schema do
    %{
      type: "object",
      properties: %{
        vega_lite_json: %{
          type: "string",
          description: "The complete Vega-Lite v5 specification, as a JSON string"
        }
      },
      required: ["vega_lite_json"]
    }
  end

  @doc "The error-text prefix used to signal an unresolvable metric name."
  def unresolvable_prefix, do: @unresolvable_prefix

  @impl true
  def execute(%{"vega_lite_json" => json}, context) do
    metric_names = Map.get(context, :metric_names, [])

    with {:ok, spec} <- Jason.decode(json),
         {:ok, _spec} <- VegaSpecValidator.validate(spec),
         :ok <- validate_metric_names(spec, metric_names) do
      {:ok, "Spec updated successfully.", %{spec: spec}}
    else
      {:error, {:unresolvable_metrics, names}} ->
        {:error, @unresolvable_prefix <> Enum.join(names, ", ")}

      {:error, errors} when is_list(errors) ->
        msg =
          "Spec failed Vega-Lite schema validation. Fix these errors and try again:\n" <>
            Enum.join(errors, "\n")

        {:error, msg}

      {:error, _} ->
        {:error, "Invalid JSON in vega_lite_json. Check syntax and try again."}
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
