defmodule MetricFlow.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :metric_flow

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn started_repo ->
          Ecto.Migrator.run(started_repo, :up, all: true)
          migrations = Ecto.Migrator.migrations(started_repo)

          if Enum.any?(migrations, fn {status, _, _} -> status != :up end) do
            raise "migration verification failed: pending migrations remain for #{inspect(repo)}"
          end

          version =
            migrations |> Enum.map(fn {_, version, _} -> version end) |> Enum.max(fn -> 0 end)

          # CodeMySpec's deploy refuses a migrate step that doesn't print this
          # proof line (`migrated=<version>`), even when the migrations ran.
          IO.puts("migrated=#{version}")
        end)
    end

    :ok
  end

  @doc """
  Prints (and returns) users whose data has no owning account yet: users who
  originated zero or several accounts, so the account-ownership migration
  could not pick one for them. Each entry lists the candidate accounts and
  unassigned row counts per table. Resolve each with
  `assign_legacy_ownership/2`.

      bin/metric_flow eval "MetricFlow.Release.legacy_ownership_report()"
  """
  def legacy_ownership_report do
    with_app_repo(fn ->
      report = MetricFlow.LegacyOwnership.report()

      if report == [] do
        IO.puts("legacy_ownership: every row has an account")
      else
        Enum.each(report, &print_legacy_entry/1)
      end

      report
    end)
  end

  @doc """
  Moves every unassigned row of `user_id` into `account_id` (the user must be
  a member). Integrations whose provider the account already has are skipped
  and listed.

      bin/metric_flow eval "MetricFlow.Release.assign_legacy_ownership(12, 34)"
  """
  def assign_legacy_ownership(user_id, account_id) do
    with_app_repo(fn ->
      result = MetricFlow.LegacyOwnership.assign(user_id, account_id)
      IO.puts("assign_legacy_ownership user=#{user_id} account=#{account_id}: #{inspect(result)}")
      result
    end)
  end

  @doc """
  Read-only: lists accounts hit by two old sync bugs, for approval before
  `purge_bad_metrics/2`.

    * `facebook_ads` — backfills stored a whole date range on one day, so an
      account's rows span far more days than they cover.
    * `google_business_reviews` — every sync re-inserted the same reviews.

      bin/metric_flow eval "MetricFlow.Release.bad_metrics_report()"
  """
  def bad_metrics_report do
    with_app_repo(fn ->
      %{rows: meta} =
        MetricFlow.Repo.query!("""
        SELECT account_id, count(*), count(DISTINCT recorded_at::date),
               (max(recorded_at)::date - min(recorded_at)::date) + 1
        FROM metrics WHERE provider = 'facebook_ads' AND account_id IS NOT NULL
        GROUP BY account_id
        HAVING (max(recorded_at)::date - min(recorded_at)::date) + 1 > 1.5 * count(DISTINCT recorded_at::date)
        """)

      %{rows: reviews} =
        MetricFlow.Repo.query!("""
        SELECT account_id, sum(n - 1) FROM (
          SELECT account_id, count(*) AS n FROM metrics
          WHERE provider = 'google_business_reviews' AND metric_name = 'review_rating'
            AND account_id IS NOT NULL
          GROUP BY account_id, dimensions->>'location_id', dimensions->>'review_id'
        ) d WHERE n > 1 GROUP BY account_id
        """)

      for [id, rows, days, span] <- meta,
          do:
            IO.puts(
              "facebook_ads account=#{id} rows=#{rows} days_with_data=#{days} span_days=#{span}"
            )

      for [id, dupes] <- reviews,
          do: IO.puts("google_business_reviews account=#{id} duplicate_reviews=#{dupes}")

      %{
        facebook_ads: Enum.map(meta, &hd/1),
        google_business_reviews: Enum.map(reviews, &hd/1)
      }
    end)
  end

  @doc """
  Deletes `provider`'s metrics (`:facebook_ads` or `:google_business_reviews`)
  for the approved `account_ids`. The next scheduled sync finds no history
  and backfills in full; "Sync now" does it immediately.

      bin/metric_flow eval "MetricFlow.Release.purge_bad_metrics(:facebook_ads, [1, 2])"
  """
  def purge_bad_metrics(provider, account_ids)
      when provider in [:facebook_ads, :google_business_reviews] and is_list(account_ids) do
    with_app_repo(fn ->
      import Ecto.Query

      {count, _} =
        from(m in "metrics",
          where: m.provider == ^Atom.to_string(provider) and m.account_id in ^account_ids
        )
        |> MetricFlow.Repo.delete_all()

      IO.puts("purge_bad_metrics #{provider} accounts=#{inspect(account_ids)} deleted=#{count}")
      count
    end)
  end

  defp print_legacy_entry(entry) do
    counts =
      entry.row_counts
      |> Enum.reject(fn {_table, count} -> count == 0 end)
      |> Enum.map_join(", ", fn {table, count} -> "#{table}=#{count}" end)

    candidates =
      Enum.map_join(entry.candidate_accounts, "; ", fn a ->
        "#{a.id} #{inspect(a.name)} (#{a.type}, role=#{a.role || "none"}#{if a.originated, do: ", originated"})"
      end)

    IO.puts(
      "user #{entry.user_id} #{entry.email} originated=#{entry.originated_account_count} " <>
        "rows: #{counts} | candidates: #{if candidates == "", do: "none", else: candidates}"
    )
  end

  # Works from a release eval (starts the repo) and from a running node's
  # remote console (the repo is already up).
  defp with_app_repo(fun) do
    load_app()

    if Process.whereis(MetricFlow.Repo) do
      fun.()
    else
      {:ok, result, _} = Ecto.Migrator.with_repo(MetricFlow.Repo, fn _repo -> fun.() end)
      result
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
