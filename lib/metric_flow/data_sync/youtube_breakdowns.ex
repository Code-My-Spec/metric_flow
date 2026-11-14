defmodule MetricFlow.DataSync.YouTubeBreakdowns do
  @moduledoc "Fetches complete breakdown slices using Analytics row-index pagination."

  alias MetricFlow.DataSync.{YouTubeBreakdownReport, YouTubeHttp}

  @url "https://youtubeanalytics.googleapis.com/v2/reports"
  @page_size 200

  def fetch(integration, channel_id, type, range, opts) do
    if type in YouTubeBreakdownReport.types() do
      fetch_page(integration, params(channel_id, type, range), type, range, opts, %{
        index: 1,
        seen: MapSet.new(),
        pages: []
      })
    else
      {:error, :invalid_breakdown_type}
    end
  end

  defp params(channel_id, type, {first, last}) do
    dimensions = Enum.join(YouTubeBreakdownReport.dimensions(type), ",")

    [
      ids: "channel==#{channel_id}",
      dimensions: dimensions,
      sort: dimensions,
      metrics: Enum.join(YouTubeBreakdownReport.metrics(), ","),
      startDate: Date.to_iso8601(first),
      endDate: Date.to_iso8601(last),
      maxResults: @page_size
    ]
  end

  defp fetch_page(integration, params, type, range, opts, state) do
    request_params = Keyword.put(params, :startIndex, state.index)

    with {:ok, body} <- YouTubeHttp.get(integration, @url, request_params, opts),
         {:ok, observations} <- YouTubeBreakdownReport.parse(body, type, range),
         {:ok, seen} <- merge_keys(observations, state.seen),
         count = length(Map.get(body, "rows", [])),
         true <- count <= @page_size do
      state = %{state | seen: seen, pages: [observations | state.pages]}
      continue_page(count, integration, params, type, range, opts, state)
    else
      false -> {:error, :malformed_report}
      {:error, _} = error -> error
    end
  end

  defp continue_page(@page_size, integration, params, type, range, opts, state) do
    fetch_page(integration, params, type, range, opts, %{state | index: state.index + @page_size})
  end

  defp continue_page(_count, _integration, _params, _type, _range, _opts, state) do
    {:ok, state.pages |> Enum.reverse() |> List.flatten()}
  end

  defp merge_keys(rows, seen) do
    Enum.reduce_while(rows, {:ok, seen}, fn row, {:ok, keys} ->
      key = {row.report_date, row.metric_name, row.breakdown_key}

      if MapSet.member?(keys, key),
        do: {:halt, {:error, :duplicate_report_page}},
        else: {:cont, {:ok, MapSet.put(keys, key)}}
    end)
  end
end
