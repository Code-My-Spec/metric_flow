# priv/repo/qa_seeds_450.exs
#
# Seeds AI insight data for story 450 QA testing.
# Creates Insight records for qa@example.com's account covering all suggestion
# types so the /insights page renders with a full populated state.
#
# Also relies on correlation results created by qa_seeds_447.exs — run that
# first to have a CorrelationResult available for the correlation_result_id
# reference on some insights.
#
# Idempotent — safe to run multiple times.
#
# Usage:
#   mix run priv/repo/qa_seeds.exs
#   mix run priv/repo/qa_seeds_447.exs
#   mix run priv/repo/qa_seeds_450.exs
#
# Requires qa_seeds.exs to have been run first.
#
# Empty-state testing:
#   Use qa-empty@example.com (created by qa_seeds.exs). That user has their own
#   isolated personal account with NO insights seeded — perfect for verifying the
#   /insights empty state UI.

import Ecto.Query

alias MetricFlow.Accounts
alias MetricFlow.Ai.AiRepository
alias MetricFlow.Ai.Insight
alias MetricFlow.Correlations.CorrelationResult
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
# 2. Resolve a CorrelationResult to link to (from qa_seeds_447.exs)
# ---------------------------------------------------------------------------

IO.puts("\n--- Resolving CorrelationResult ---")

correlation_result =
  Repo.one(
    from r in CorrelationResult,
      where: r.account_id == ^account_id,
      order_by: [desc: r.inserted_at],
      limit: 1
  )

if correlation_result do
  IO.puts("  Found CorrelationResult id=#{correlation_result.id} (#{correlation_result.metric_name})")
else
  IO.puts("  No CorrelationResult found — insights will not link to a correlation result")
  IO.puts("  Run priv/repo/qa_seeds_447.exs first to create correlation data")
end

correlation_result_id = if correlation_result, do: correlation_result.id, else: nil

# ---------------------------------------------------------------------------
# 3. Create Insight records (idempotent — skip if insights already exist)
# ---------------------------------------------------------------------------

IO.puts("\n--- Insights ---")

existing_count =
  Repo.one(from i in Insight, where: i.account_id == ^account_id, select: count())

if existing_count > 0 do
  IO.puts("  #{existing_count} insight(s) already exist for account #{account_id} — skipping")
else
  now = DateTime.utc_now()

  insights_attrs = [
    %{
      summary: "Increase Google Ads budget to capitalize on strong revenue correlation",
      content:
        "Your Google Ads clicks metric shows a strong positive correlation of 0.82 with revenue " <>
          "(7-day lag). This suggests that increasing your Google Ads budget is likely to drive " <>
          "meaningful revenue growth. Consider increasing spend by 15–25% and monitoring results " <>
          "over the next 2–3 weeks.",
      suggestion_type: :budget_increase,
      confidence: 0.85,
      correlation_result_id: correlation_result_id,
      generated_at: now,
      metadata: %{
        "metric_name" => "clicks",
        "goal_metric_name" => "revenue",
        "coefficient" => 0.82,
        "optimal_lag" => 7,
        "provider" => "google_ads"
      }
    },
    %{
      summary: "Optimize Facebook Ads targeting — moderate impressions correlation",
      content:
        "Facebook Ads impressions have a moderate positive correlation (0.51) with revenue at a " <>
          "14-day lag. Rather than increasing overall budget, optimizing your targeting to reach " <>
          "higher-intent audiences may improve the conversion rate of these impressions into revenue.",
      suggestion_type: :optimization,
      confidence: 0.72,
      correlation_result_id: nil,
      generated_at: DateTime.add(now, -3600, :second),
      metadata: %{
        "metric_name" => "impressions",
        "goal_metric_name" => "revenue",
        "coefficient" => 0.51,
        "provider" => "facebook_ads"
      }
    },
    %{
      summary: "Monitor Google Analytics sessions — weak correlation with revenue",
      content:
        "Website sessions from Google Analytics show a weak positive correlation (0.29) with revenue " <>
          "at a 5-day lag. This relationship is not strong enough to base budget decisions on. " <>
          "Continue monitoring over the next 30 days to see if the correlation strengthens.",
      suggestion_type: :monitoring,
      confidence: 0.55,
      correlation_result_id: nil,
      generated_at: DateTime.add(now, -7200, :second),
      metadata: %{
        "metric_name" => "sessions",
        "goal_metric_name" => "revenue",
        "coefficient" => 0.29,
        "provider" => "google_analytics"
      }
    },
    %{
      summary: "Review ad spend allocation — negative income correlation detected",
      content:
        "QuickBooks income shows a negative correlation (-0.38) with revenue. This may indicate " <>
          "that during high-cost periods, revenue is being suppressed. Review your cost structure " <>
          "and consider reducing overhead expenses during campaign-heavy periods.",
      suggestion_type: :budget_decrease,
      confidence: 0.63,
      correlation_result_id: nil,
      generated_at: DateTime.add(now, -10_800, :second),
      metadata: %{
        "metric_name" => "income",
        "goal_metric_name" => "revenue",
        "coefficient" => -0.38,
        "provider" => "quickbooks"
      }
    },
    %{
      summary: "Strong spend-to-revenue relationship across platforms",
      content:
        "Across your connected platforms, ad spend shows a consistent positive correlation (0.74) " <>
          "with revenue at a 3-day lag. This is a general indicator that your overall marketing " <>
          "investment is working. Continue your current strategy and review quarterly.",
      suggestion_type: :general,
      confidence: 0.78,
      correlation_result_id: nil,
      generated_at: DateTime.add(now, -14_400, :second),
      metadata: %{
        "metric_name" => "spend",
        "goal_metric_name" => "revenue",
        "coefficient" => 0.74,
        "provider" => "google_ads"
      }
    }
  ]

  Enum.each(insights_attrs, fn attrs ->
    full_attrs = Map.put(attrs, :account_id, account_id)

    case AiRepository.create_insight(scope, full_attrs) do
      {:ok, insight} ->
        IO.puts("  Created: [#{insight.suggestion_type}] #{insight.summary} (id=#{insight.id}, confidence=#{insight.confidence})")

      {:error, changeset} ->
        IO.puts("  ERROR creating insight: #{inspect(changeset.errors)}")
    end
  end)
end

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

final_count = Repo.one(from i in Insight, where: i.account_id == ^account_id, select: count())

IO.puts("""

==========================================
 QA Seeds 450 — AI Insights Data
==========================================

Insights created for: qa@example.com
  Total insights:     #{final_count}
  Suggestion types:   budget_increase, optimization, monitoring, budget_decrease, general
  Correlation ref:    #{if correlation_result_id, do: "CorrelationResult ##{correlation_result_id}", else: "none (run qa_seeds_447.exs first)"}

Empty-state user:   qa-empty@example.com
  This user has their own isolated personal account with NO insights.
  Use this account to test the /insights empty state.
  Created by qa_seeds.exs — no additional seeding required.

Login:  http://localhost:4070/users/log-in
Owner:  qa@example.com / hello world!
Empty:  qa-empty@example.com / hello world!

Test populated: http://localhost:4070/insights  (as qa@example.com)
Test empty:     http://localhost:4070/insights  (as qa-empty@example.com)
==========================================
""")
