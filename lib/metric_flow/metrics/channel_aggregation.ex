defmodule MetricFlow.Metrics.ChannelAggregation do
  @moduledoc "Aggregates channel samples while preserving snapshot and ratio semantics."

  def value([], _semantics), do: nil

  def value(samples, semantics) do
    if samples |> Enum.map(& &1.unit) |> Enum.uniq() |> length() == 1 do
      aggregate(samples, semantics)
    else
      nil
    end
  end

  defp aggregate(samples, :sum), do: sum(samples)

  defp aggregate(samples, :latest) do
    samples
    |> Enum.group_by(& &1.entity_id)
    |> Enum.map(fn {_id, rows} -> Enum.max_by(rows, & &1.date, Date) end)
    |> sum()
  end

  defp aggregate([sample], :per_entity), do: sample.value
  defp aggregate(_samples, :per_entity), do: nil

  defp aggregate(samples, {:weighted, _denominator}) do
    if Enum.all?(samples, &(is_number(&1.weight) and &1.weight >= 0)) do
      weight = Enum.reduce(samples, 0.0, &(&1.weight + &2))

      if weight > 0 do
        Enum.reduce(samples, 0.0, &(&1.value * &1.weight + &2)) / weight
      else
        nil
      end
    else
      nil
    end
  end

  defp sum(samples), do: Enum.reduce(samples, 0.0, &(&1.value + &2))
end
