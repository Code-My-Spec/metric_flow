# priv/repo/qa_seeds_444.exs
#
# Seeds canned (built-in) dashboards for Story 444 QA testing.
# Idempotent — safe to run multiple times.
#
# Usage: mix run priv/repo/qa_seeds_444.exs
#
# Creates:
#   - "Marketing Overview" canned dashboard (built_in: true)
#   - "Revenue Analysis" canned dashboard (built_in: true)
#   - "Platform Comparison" canned dashboard (built_in: true)
#
# Note: built_in dashboards are associated with the qa@example.com user because
# the Dashboard schema requires a user_id. In production, canned dashboards would
# be seeded with a system user or via a migration. For QA purposes the qa user
# is sufficient.

alias MetricFlow.{Repo, Users}
alias MetricFlow.Dashboards.Dashboard

import Ecto.Query

IO.puts("\n--- QA Owner User (required for canned dashboard user_id) ---")

qa_user =
  case Users.get_user_by_email("qa@example.com") do
    nil ->
      IO.puts("  ERROR: qa@example.com not found — run qa_seeds.exs first")
      System.halt(1)

    user ->
      IO.puts("  Found: #{user.email}")
      user
  end

# ---------------------------------------------------------------------------
# Canned dashboards
# ---------------------------------------------------------------------------

IO.puts("\n--- Canned Dashboards ---")

canned_dashboards = [
  %{
    name: "Marketing Overview",
    description: "Pre-built marketing performance dashboard with channel breakdown and trend analysis.",
    built_in: true
  },
  %{
    name: "Revenue Analysis",
    description: "Pre-built revenue tracking dashboard showing MRR, ARR, and growth trends.",
    built_in: true
  },
  %{
    name: "Platform Comparison",
    description: "Pre-built cross-platform comparison dashboard for ad spend and performance.",
    built_in: true
  }
]

Enum.each(canned_dashboards, fn attrs ->
  existing =
    Repo.one(
      from(d in Dashboard,
        where: d.name == ^attrs.name and d.built_in == true,
        limit: 1
      )
    )

  case existing do
    nil ->
      %Dashboard{}
      |> Dashboard.changeset(Map.put(attrs, :user_id, qa_user.id))
      |> Repo.insert!()

      IO.puts("  Created: #{attrs.name}")

    _found ->
      IO.puts("  Exists: #{attrs.name}")
  end
end)

IO.puts("""

==========================================
 Story 444 Seed Data
==========================================

Canned dashboards created for qa@example.com:
  - Marketing Overview (built_in: true)
  - Revenue Analysis (built_in: true)
  - Platform Comparison (built_in: true)

Navigate to: http://localhost:4070/dashboards
==========================================
""")
