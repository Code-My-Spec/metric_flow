defmodule MetricFlow.DataSync.YouTubeBreakdownSync do
  @moduledoc "Stores independently resumable channel breakdown report slices."

  alias MetricFlow.DataSync.{YouTubeBreakdownReport, YouTubeBreakdowns, YouTubeReports}
  alias MetricFlow.Metrics

  @timezone "America/Los_Angeles"

  def sync(scope, integration, channel, created_on, today, fetched_at, opts) do
    first = Enum.max([created_on, Date.add(today, -548)], Date)
    last = Date.add(today, -1)

    result =
      with {:ok, availability_start} <- earliest_unfinished(scope, channel.id, first),
           do:
             YouTubeReports.fetch(
               integration,
               channel.external_id,
               YouTubeBreakdownReport.metrics(),
               {availability_start, last},
               opts
             )

    case result do
      {:ok, %{through_date: nil}} ->
        []

      {:ok, %{through_date: available}} ->
        Enum.map(YouTubeBreakdownReport.types(), fn type ->
          result =
            sync_type(scope, integration, channel, type, {first, available}, fetched_at, opts)

          outcome(channel, type, result)
        end)

      {:error, _} = error ->
        [outcome(channel, "availability", error)]
    end
  end

  defp earliest_unfinished(scope, entity_id, initial) do
    result =
      Enum.reduce_while(YouTubeBreakdownReport.types(), {:ok, []}, fn type, {:ok, dates} ->
        case Metrics.get_entity_cursor(scope, entity_id, "analytics", @timezone, type) do
          {:ok, nil} -> {:cont, {:ok, [initial | dates]}}
          {:ok, date} -> {:cont, {:ok, [Date.add(date, 1) | dates]}}
          {:error, _} = error -> {:halt, error}
        end
      end)

    case result do
      {:ok, dates} -> {:ok, Enum.min(dates, Date)}
      error -> error
    end
  end

  defp sync_type(scope, integration, channel, type, {initial, last}, fetched_at, opts) do
    with {:ok, cursor} <-
           Metrics.get_entity_cursor(scope, channel.id, "analytics", @timezone, type) do
      first = if cursor, do: Date.add(cursor, 1), else: initial
      sync_slices(scope, integration, channel, type, {first, last}, fetched_at, opts, 0)
    end
  end

  defp sync_slices(scope, integration, channel, type, {first, last}, fetched_at, opts, count) do
    if Date.compare(first, last) == :gt do
      {:ok, %{observations_written: count}}
    else
      finish = slice_end(type, first, last)
      result = persist_slice(scope, integration, channel, type, {first, finish}, fetched_at, opts)

      continue_slices(
        result,
        scope,
        integration,
        channel,
        type,
        {Date.add(finish, 1), last},
        fetched_at,
        opts,
        count
      )
    end
  end

  defp persist_slice(scope, integration, channel, type, range, fetched_at, opts) do
    with {:ok, rows} <-
           YouTubeBreakdowns.fetch(integration, channel.external_id, type, range, opts) do
      Metrics.persist_entity_report(scope, channel.id, "analytics", type, range, rows, fetched_at)
    end
  end

  defp continue_slices(
         {:ok, result},
         scope,
         integration,
         channel,
         type,
         range,
         fetched_at,
         opts,
         count
       ) do
    sync_slices(
      scope,
      integration,
      channel,
      type,
      range,
      fetched_at,
      opts,
      count + result.observations_written
    )
  end

  defp continue_slices(
         {:error, _} = error,
         _scope,
         _integration,
         _channel,
         _type,
         _range,
         _fetched_at,
         _opts,
         _count
       ),
       do: error

  defp slice_end("country", first, _last), do: first
  defp slice_end(_type, first, last), do: Enum.min([Date.add(first, 179), last], Date)

  defp outcome(channel, type, result),
    do: %{channel_id: channel.external_id, family: "breakdown_#{type}", result: result}
end
