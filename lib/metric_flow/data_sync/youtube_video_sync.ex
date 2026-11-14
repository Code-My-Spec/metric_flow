defmodule MetricFlow.DataSync.YouTubeVideoSync do
  @moduledoc "Stores video metadata and independent daily analytics and revenue reports."

  alias MetricFlow.DataSync.{YouTubeReports, YouTubeVideos}
  alias MetricFlow.Metrics

  @timezone "America/Los_Angeles"
  @revenue_scope "https://www.googleapis.com/auth/yt-analytics-monetary.readonly"

  def sync(scope, integration, channel, playlist_id, today, fetched_at, opts) do
    case YouTubeVideos.fetch(integration, channel.external_id, playlist_id, opts) do
      {:ok, videos} ->
        Enum.flat_map(videos, fn video ->
          sync_video(scope, integration, channel, video, today, fetched_at, opts)
        end)

      {:error, _} = error ->
        [outcome(channel, "video_inventory", error)]
    end
  end

  defp sync_video(scope, integration, channel, video, today, fetched_at, opts) do
    case Metrics.upsert_video(scope, channel.id, video.external_id, video.attrs) do
      {:ok, entity} ->
        Enum.map(["analytics", "revenue"], fn family ->
          result =
            sync_family(scope, integration, channel, entity, family, today, fetched_at, opts)

          outcome(channel, "video_#{family}", result)
        end)

      {:error, _} = error ->
        [outcome(channel, "video_metadata", error)]
    end
  end

  defp sync_family(scope, integration, channel, video, family, today, fetched_at, opts) do
    if family == "revenue" and @revenue_scope not in (integration.granted_scopes || []) do
      {:skipped, :missing_revenue_permission}
    else
      fetch_family(scope, integration, channel, video, family, today, fetched_at, opts)
    end
  end

  defp fetch_family(scope, integration, channel, video, family, today, fetched_at, opts) do
    with {:ok, cursor} <- Metrics.get_entity_cursor(scope, video.id, family, @timezone, "total") do
      first = first_date(cursor, video.published_at, today)
      last = Date.add(today, -1)
      names = Metrics.youtube_metric_names(family)
      opts = if family == "revenue", do: Keyword.put(opts, :currency, "USD"), else: opts

      with {:ok, report} <-
             YouTubeReports.fetch_video(
               integration,
               channel.external_id,
               video.external_id,
               names,
               {first, last},
               opts
             ) do
        persist_available(scope, video.id, family, first, report, fetched_at)
      end
    end
  end

  defp first_date(nil, published_at, today),
    do: Enum.max([DateTime.to_date(published_at), Date.add(today, -548)], Date)

  defp first_date(cursor, _published_at, _today), do: Date.add(cursor, 1)

  defp persist_available(_scope, _id, _family, _first, %{through_date: nil}, _fetched_at),
    do: {:ok, %{observations_written: 0, through_date: nil}}

  defp persist_available(scope, id, family, first, report, fetched_at) do
    Metrics.persist_entity_report(
      scope,
      id,
      family,
      "total",
      {first, report.through_date},
      report.observations,
      fetched_at
    )
  end

  defp outcome(channel, family, result),
    do: %{channel_id: channel.external_id, family: family, result: result}
end
