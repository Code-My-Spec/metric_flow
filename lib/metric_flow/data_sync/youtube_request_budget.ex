defmodule MetricFlow.DataSync.YouTubeRequestBudget do
  @moduledoc "Shared daily request accounting for YouTube sync workers."

  alias MetricFlow.Repo

  # Reserve headroom for connection discovery and other project consumers.
  # Deployments can lower these allocations to match their Cloud project.
  @defaults %{"data" => 9000, "analytics" => 9000}

  def reserve(api, now) when api in ["data", "analytics"] do
    limits = Application.get_env(:metric_flow, :youtube_daily_request_budgets, @defaults)
    limit = Map.get(limits, api, Map.fetch!(@defaults, api))

    if is_integer(limit) and limit > 0 do
      reserve_request(api, now, limit)
    else
      {:error, :quota_exceeded}
    end
  end

  def block(api, window) do
    case Repo.query(
           """
           UPDATE youtube_request_budgets SET blocked = TRUE
           WHERE api = $1 AND window_started_at = $2
           """,
           [api, window]
         ) do
      {:ok, _} -> :ok
      {:error, _} -> {:error, :quota_accounting_failed}
    end
  end

  defp reserve_request(api, now, limit) do
    sql = """
    INSERT INTO youtube_request_budgets AS budget
      (api, window_started_at, requests, blocked)
    VALUES ($1,
      (date_trunc('day', $2::timestamptz AT TIME ZONE 'America/Los_Angeles')
        AT TIME ZONE 'America/Los_Angeles') AT TIME ZONE 'UTC',
      1, FALSE)
    ON CONFLICT (api) DO UPDATE SET
      window_started_at = EXCLUDED.window_started_at,
      requests = CASE WHEN budget.window_started_at < EXCLUDED.window_started_at
        THEN 1 ELSE budget.requests + 1 END,
      blocked = FALSE
    WHERE budget.window_started_at < EXCLUDED.window_started_at
      OR (budget.window_started_at = EXCLUDED.window_started_at
        AND NOT budget.blocked AND budget.requests < $3)
    RETURNING window_started_at
    """

    case Repo.query(sql, [api, now, limit]) do
      {:ok, %{rows: [[window]]}} -> {:ok, window}
      {:ok, %{rows: []}} -> {:error, :quota_exceeded}
      {:error, _} -> {:error, :quota_accounting_failed}
    end
  end
end
