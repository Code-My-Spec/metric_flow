defmodule MetricFlow.DataSync.YouTubeReports do
  @moduledoc "Fetches complete channel-total daily tables in bounded date slices."

  alias MetricFlow.DataSync.{YouTubeHttp, YouTubeReport}

  @url "https://youtubeanalytics.googleapis.com/v2/reports"
  @slice_days 180

  def fetch(integration, channel_id, names, {first, last}, opts \\ []) do
    if Date.compare(first, last) == :gt do
      {:ok, %{observations: [], through_date: nil}}
    else
      fetch_slices(integration, channel_id, names, first, last, opts, [])
    end
  end

  def fetch_video(integration, channel_id, video_id, names, range, opts)
      when is_binary(video_id) do
    if Regex.match?(~r/\A[A-Za-z0-9_-]+\z/, video_id) do
      fetch(integration, channel_id, names, range, Keyword.put(opts, :video_id, video_id))
    else
      {:error, :invalid_video_id}
    end
  end

  defp fetch_slices(integration, channel_id, names, first, last, opts, acc) do
    slice_last = Enum.min([Date.add(first, @slice_days - 1), last], Date)

    params = [
      ids: "channel==#{channel_id}",
      dimensions: "day",
      metrics: Enum.join(names, ","),
      startDate: Date.to_iso8601(first),
      endDate: Date.to_iso8601(slice_last),
      sort: "day",
      maxResults: 200,
      startIndex: 1
    ]

    params =
      if Keyword.get(opts, :currency),
        do: Keyword.put(params, :currency, Keyword.fetch!(opts, :currency)),
        else: params

    params =
      case Keyword.fetch(opts, :video_id) do
        {:ok, video_id} -> Keyword.put(params, :filters, "video==#{video_id}")
        :error -> params
      end

    # With day as the only dimension, a 180-day slice has at most 180 rows.
    # Asking for 200 avoids truncation without relying on page-token support.
    with {:ok, body} <- YouTubeHttp.get(integration, @url, params, opts),
         {:ok, rows} <- YouTubeReport.parse(body, names, {first, slice_last}) do
      acc = [rows | acc]

      if Date.compare(slice_last, last) == :lt do
        fetch_slices(integration, channel_id, names, Date.add(slice_last, 1), last, opts, acc)
      else
        observations = acc |> Enum.reverse() |> List.flatten()
        through_date = observations |> Enum.map(& &1.report_date) |> Enum.max(Date, fn -> nil end)
        {:ok, %{observations: observations, through_date: through_date}}
      end
    end
  end
end
