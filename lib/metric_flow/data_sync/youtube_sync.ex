defmodule MetricFlow.DataSync.YouTubeSync do
  @moduledoc "Syncs selected account-owned channels with independent report outcomes."

  alias MetricFlow.DataSync.{YouTubeChannel, YouTubeHttp, YouTubeReports}
  alias MetricFlow.Integrations
  alias MetricFlow.Metrics

  @channels_url "https://www.googleapis.com/youtube/v3/channels"
  @timezone "America/Los_Angeles"
  @revenue_scope "https://www.googleapis.com/auth/yt-analytics-monetary.readonly"

  def sync(scope, integration, opts \\ []) do
    with {:ok, authorized} <- Integrations.get_integration(scope, :youtube),
         true <- authorized.id == integration.id,
         {:ok, ids} <- selected_channels(authorized) do
      today = today()
      outcomes = Enum.flat_map(ids, &sync_channel(scope, integration, &1, today, opts))
      {:ok, outcomes}
    else
      false -> {:error, :unauthorized}
      {:error, _} = error -> error
    end
  end

  defp selected_channels(integration) do
    ids = Map.get(integration.provider_metadata || %{}, "channel_ids", [])

    if is_list(ids) and ids != [] and Enum.all?(ids, &(is_binary(&1) and &1 != "")),
      do: {:ok, Enum.uniq(ids)},
      else: {:error, :missing_channels}
  end

  defp sync_channel(scope, integration, id, today, opts) do
    fetched_at = now()
    params = [id: id, part: "snippet,statistics"]

    with {:ok, body} <- YouTubeHttp.get(integration, @channels_url, params, opts),
         {:ok, channel} <- YouTubeChannel.parse(body, id, today),
         {:ok, entity} <- Metrics.upsert_channel(scope, id, channel.attrs) do
      snapshot =
        Metrics.persist_report(
          scope,
          entity.id,
          "snapshot",
          {today, today},
          channel.snapshots,
          fetched_at
        )

      reports =
        Enum.map(["analytics", "revenue"], fn family ->
          result =
            sync_family(scope, integration, entity, channel.created_on, family, today, opts)

          outcome(id, family, result)
        end)

      [outcome(id, "snapshot", snapshot) | reports]
    else
      {:error, reason} -> [outcome(id, "channel", {:error, reason})]
    end
  end

  defp sync_family(scope, integration, entity, created_on, family, today, opts) do
    if family == "revenue" and @revenue_scope not in (integration.granted_scopes || []) do
      {:skipped, :missing_revenue_permission}
    else
      fetch_family(scope, integration, entity, created_on, family, today, opts)
    end
  end

  defp fetch_family(scope, integration, entity, created_on, family, today, opts) do
    with {:ok, cursor} <- Metrics.get_cursor(scope, entity.id, family, @timezone) do
      first =
        if cursor,
          do: Date.add(cursor, 1),
          else: Enum.max([created_on, Date.add(today, -548)], Date)

      last = Date.add(today, -1)
      fetched_at = now()
      names = Metrics.youtube_metric_names(family)
      opts = if family == "revenue", do: Keyword.put(opts, :currency, "USD"), else: opts

      with {:ok, report} <-
             YouTubeReports.fetch(integration, entity.external_id, names, {first, last}, opts) do
        persist_available(scope, entity.id, family, first, report, fetched_at)
      end
    end
  end

  # Empty reports do not establish availability. Keep the cursor and prior
  # observations so delayed data will be requested again.
  defp persist_available(_scope, _id, _family, _first, %{through_date: nil}, _fetched_at),
    do: {:ok, %{observations_written: 0, through_date: nil}}

  defp persist_available(scope, id, family, first, report, fetched_at) do
    Metrics.persist_report(
      scope,
      id,
      family,
      {first, report.through_date},
      report.observations,
      fetched_at
    )
  end

  defp outcome(channel_id, family, result),
    do: %{channel_id: channel_id, family: family, result: result}

  defp today do
    case Application.get_env(:metric_flow, :sync_clock) do
      nil -> Date.utc_today()
      clock -> clock.utc_today()
    end
  end

  defp now do
    case Application.get_env(:metric_flow, :sync_clock) do
      nil -> DateTime.utc_now()
      clock -> clock.utc_now()
    end
  end
end
