# priv/repo/qa_seeds_447.exs
#
# Seeds correlation data for story 447 QA testing.
# Creates a completed CorrelationJob with several CorrelationResult rows so
# the /correlations page renders in its data state (Raw mode table visible).
#
# Also confirms the page correctly shows the no-data empty state for a fresh
# user — the qa@example.com user is used for the data state and
# qa-member@example.com is left without correlation data.
#
# Idempotent — safe to run multiple times.
#
# Usage: mix run priv/repo/qa_seeds_447.exs
#
# Requires qa_seeds.exs to have been run first (users and team account must exist).

import Ecto.Query

alias MetricFlow.Accounts
alias MetricFlow.Correlations.CorrelationJob
alias MetricFlow.Correlations.CorrelationResult
alias MetricFlow.Correlations.CorrelationsRepository
alias MetricFlow.Repo
alias MetricFlow.Users
alias MetricFlow.Users.Scope

# ---------------------------------------------------------------------------
# 1. Resolve qa@example.com and build scope
# ---------------------------------------------------------------------------

IO.puts("\n--- Resolving qa@example.com ---")

qa_user = Users.get_user_by_email("qa@example.com")

unless qa_user do
  raise "qa@example.com not found — run priv/repo/qa_seeds.exs first"
end

IO.puts("  Found: #{qa_user.email}")

scope = Scope.for_user(qa_user)
account_id = Accounts.get_personal_account_id(scope)

IO.puts("  Personal account_id: #{account_id}")

# ---------------------------------------------------------------------------
# 2. Create or reuse a completed CorrelationJob
# ---------------------------------------------------------------------------

IO.puts("\n--- CorrelationJob ---")

existing_job =
  Repo.one(
    from j in CorrelationJob,
      where: j.account_id == ^account_id and j.status == :completed,
      order_by: [desc: j.inserted_at],
      limit: 1
  )

job =
  case existing_job do
    nil ->
      now = DateTime.utc_now()
      window_start = Date.add(Date.utc_today(), -90)
      window_end = Date.add(Date.utc_today(), -1)

      {:ok, new_job} =
        %CorrelationJob{}
        |> CorrelationJob.changeset(%{
          account_id: account_id,
          status: :completed,
          goal_metric_name: "revenue",
          data_window_start: window_start,
          data_window_end: window_end,
          data_points: 90,
          results_count: 5,
          started_at: DateTime.add(now, -120, :second),
          completed_at: DateTime.add(now, -5, :second)
        })
        |> Repo.insert()

      IO.puts("  Created CorrelationJob id=#{new_job.id}")
      new_job

    existing ->
      IO.puts("  Exists: CorrelationJob id=#{existing.id}")
      existing
  end

# ---------------------------------------------------------------------------
# 3. Create CorrelationResult rows (idempotent — skip if any exist for job)
# ---------------------------------------------------------------------------

IO.puts("\n--- CorrelationResults ---")

results_exist =
  Repo.exists?(
    from r in CorrelationResult,
      where: r.correlation_job_id == ^job.id
  )

if results_exist do
  IO.puts("  Results already exist for job #{job.id} — skipping")
else
  now = DateTime.utc_now()

  results_attrs = [
    %{
      metric_name: "clicks",
      goal_metric_name: "revenue",
      coefficient: 0.82,
      optimal_lag: 7,
      data_points: 90,
      provider: :google_ads,
      calculated_at: now
    },
    %{
      metric_name: "spend",
      goal_metric_name: "revenue",
      coefficient: 0.74,
      optimal_lag: 3,
      data_points: 90,
      provider: :google_ads,
      calculated_at: now
    },
    %{
      metric_name: "impressions",
      goal_metric_name: "revenue",
      coefficient: 0.51,
      optimal_lag: 14,
      data_points: 90,
      provider: :facebook_ads,
      calculated_at: now
    },
    %{
      metric_name: "income",
      goal_metric_name: "revenue",
      coefficient: -0.38,
      optimal_lag: 0,
      data_points: 90,
      provider: :quickbooks,
      calculated_at: now
    },
    %{
      metric_name: "sessions",
      goal_metric_name: "revenue",
      coefficient: 0.29,
      optimal_lag: 5,
      data_points: 90,
      provider: :google_analytics,
      calculated_at: now
    }
  ]

  Enum.each(results_attrs, fn attrs ->
    {:ok, result} =
      %CorrelationResult{}
      |> CorrelationResult.changeset(
        Map.merge(attrs, %{account_id: account_id, correlation_job_id: job.id})
      )
      |> Repo.insert()

    IO.puts(
      "  Created: #{result.metric_name} -> revenue (#{result.coefficient}, lag=#{result.optimal_lag}, #{result.provider})"
    )
  end)
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

IO.puts("""

==========================================
 QA Seeds 447 — Correlation Data
==========================================

Correlation data created for: qa@example.com
  Goal metric:   revenue
  Job status:    completed
  Data window:   90 days
  Results:       5 metrics (google_ads, facebook_ads, quickbooks, google_analytics)
  Providers:     google_ads (clicks, spend), facebook_ads (impressions),
                 quickbooks (income), google_analytics (sessions)

No-data state:   qa-member@example.com (no correlation data, use for empty state tests)

Login:  http://localhost:4070/users/log-in
Owner:  qa@example.com / hello world!
Member: qa-member@example.com / hello world!
==========================================
""")
