defmodule MetricFlow.Metrics.EntityReportSlice do
  @moduledoc """
  Shapes stored daily entity observations for a provider's report.

  Each row retains its entity, day, metric name, and value so locations on
  the same day remain distinct and a stored zero remains visible.
  """

  alias MetricFlow.Metrics.EntityMetricObservation

  @type daily_row :: %{
          entity_id: String.t(),
          date: Date.t(),
          metric_name: String.t(),
          value: float()
        }
  @type t :: %{provider: atom(), metric_names: [String.t()], daily_rows: [daily_row()]}

  @spec build([EntityMetricObservation.t()], atom()) :: t()
  def build(observations, provider) when is_list(observations) and is_atom(provider) do
    daily_rows =
      observations
      |> Enum.filter(&(&1.provider == provider))
      |> Enum.map(fn observation ->
        %{
          entity_id: observation.entity_id,
          date: observation.observed_on,
          metric_name: observation.metric_name,
          value: observation.value
        }
      end)
      |> Enum.sort_by(&{&1.date, &1.entity_id, &1.metric_name})

    %{
      provider: provider,
      metric_names: daily_rows |> Enum.map(& &1.metric_name) |> Enum.uniq() |> Enum.sort(),
      daily_rows: daily_rows
    }
  end

  @spec for_entity(t(), String.t()) :: [daily_row()]
  def for_entity(%{daily_rows: rows}, entity_id) when is_binary(entity_id) do
    Enum.filter(rows, &(&1.entity_id == entity_id))
  end
end
