# priv/repo/qa_metric_seeds.exs
#
# Synthetic 90-day metric history for qa@example.com, so dashboard demos
# have real-looking data through yesterday instead of whatever date a
# past sync happened to stop at. Dev QA data only -- never product data.
#
# Usage: DATABASE_NAME=<dev db name> mix run priv/repo/qa_metric_seeds.exs
#
# Requires priv/repo/qa_seeds.exs to have been run first (qa@example.com
# must exist). Idempotent -- deletes and recreates only the synthetic rows
# it owns (dimensions["synthetic"] == true) for qa@example.com's
# impressions/clicks/cost/sessions; nothing else is touched.

alias MetricFlow.Metrics.{Metric, NormalizedMetric}
alias MetricFlow.Repo
alias MetricFlow.Users

import Ecto.Query

unless Mix.env() == :dev do
  raise "qa_metric_seeds.exs only runs in :dev (got #{Mix.env()}) -- it writes synthetic demo data and must never touch test or prod"
end

database_name = System.get_env("DATABASE_NAME")

unless database_name do
  raise "DATABASE_NAME must be set -- refusing to guess which dev database to write synthetic metrics into"
end

IO.puts("Target database: #{database_name}")

qa_user = Users.get_user_by_email("qa@example.com")

unless qa_user do
  raise "qa@example.com not found -- run priv/repo/qa_seeds.exs first"
end

IO.puts("Seeding synthetic metrics for #{qa_user.email} (user_id=#{qa_user.id})")

# ---------------------------------------------------------------------------
# 1. Idempotency: delete only previously-seeded synthetic rows for this
#    user and these metrics -- real synced data is never touched.
# ---------------------------------------------------------------------------

metric_names = ["impressions", "clicks", "cost", "sessions"]

{deleted_count, _} =
  Repo.delete_all(
    from(m in Metric,
      where: m.user_id == ^qa_user.id,
      where: m.metric_name in ^metric_names,
      where: fragment("?->>'synthetic' = 'true'", m.dimensions)
    )
  )

IO.puts("  Deleted #{deleted_count} previously-seeded synthetic row(s)")

# ---------------------------------------------------------------------------
# 2. Deterministic generation: fixed seed so reruns produce identical
#    values, not just the same row count -- true idempotency.
# ---------------------------------------------------------------------------

:rand.seed(:exsss, {12_345, 67_890, 11_121})

today = Date.utc_today()
window_end = Date.add(today, -1)
window_start = Date.add(today, -90)
days = Date.range(window_start, window_end) |> Enum.to_list()
day_count = length(days)

noise = fn -> 0.9 + :rand.uniform() * 0.2 end

weekend_multiplier = fn date ->
  if Date.day_of_week(date) in [6, 7], do: 0.7, else: 1.0
end

now = DateTime.utc_now()

rows =
  days
  |> Enum.with_index()
  |> Enum.flat_map(fn {date, idx} ->
    recorded_at = DateTime.new!(date, ~T[00:00:00.000000], "Etc/UTC")
    # Mild upward trend over the window: ~30% higher by the most recent day.
    trend = 1.0 + idx / (day_count - 1) * 0.3
    seasonality = weekend_multiplier.(date)

    impressions = max(round(3500 * seasonality * trend * noise.()), 0)
    clicks = max(round(impressions * 0.03 * noise.()), 0)
    cost = Float.round(clicks * 0.8 * noise.(), 2)
    sessions = max(round(450 * seasonality * trend * noise.()), 0)

    dimensions = %{"synthetic" => true}

    [
      %{
        metric_type: "advertising",
        metric_name: "impressions",
        normalized_metric_name: NormalizedMetric.normalize(:google_ads, "impressions"),
        value: impressions * 1.0,
        recorded_at: recorded_at,
        provider: :google_ads,
        dimensions: dimensions,
        user_id: qa_user.id,
        inserted_at: now,
        updated_at: now
      },
      %{
        metric_type: "advertising",
        metric_name: "clicks",
        normalized_metric_name: NormalizedMetric.normalize(:google_ads, "clicks"),
        value: clicks * 1.0,
        recorded_at: recorded_at,
        provider: :google_ads,
        dimensions: dimensions,
        user_id: qa_user.id,
        inserted_at: now,
        updated_at: now
      },
      %{
        metric_type: "advertising",
        metric_name: "cost",
        normalized_metric_name: NormalizedMetric.normalize(:google_ads, "cost"),
        value: cost,
        recorded_at: recorded_at,
        provider: :google_ads,
        dimensions: dimensions,
        user_id: qa_user.id,
        inserted_at: now,
        updated_at: now
      },
      %{
        metric_type: "traffic",
        metric_name: "sessions",
        normalized_metric_name: NormalizedMetric.normalize(:google_analytics, "sessions"),
        value: sessions * 1.0,
        recorded_at: recorded_at,
        provider: :google_analytics,
        dimensions: dimensions,
        user_id: qa_user.id,
        inserted_at: now,
        updated_at: now
      }
    ]
  end)

{inserted_count, _} = Repo.insert_all(Metric, rows)

IO.puts("  Inserted #{inserted_count} synthetic metric row(s) (#{day_count} days x 4 metrics)")

IO.puts("""

==========================================
 QA Metric Seeds -- Synthetic Demo Data
==========================================

Database:   #{database_name}
User:       #{qa_user.email}
Window:     #{window_start} .. #{window_end} (#{day_count} days)
Metrics:    google_ads impressions/clicks/cost, google_analytics sessions
Marked:     dimensions["synthetic"] = true (safe to re-delete/rerun)
==========================================
""")
