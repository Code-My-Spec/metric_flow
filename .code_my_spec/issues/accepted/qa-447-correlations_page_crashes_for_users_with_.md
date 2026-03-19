# Correlations page crashes for users with no team account (list_correlation_jobs nil guard missing)

## Status

resolved

## Severity

high

## Scope

app

## Description

When a user with no team account (personal account only) navigates to  /correlations , the page renders a 500 error instead of the expected no-data empty state. This issue persists from the previous QA run — the partial fix applied to  get_latest_completed_job  did not extend to  list_correlation_jobs . Reproduction steps: Log in as  qa-empty@example.com  (personal account only, no team membership) Navigate to  http://localhost:4070/correlations Error:   ArgumentError: nil given for account_id. comparison with nil is forbidden Stack trace location:   lib/metric_flow/correlations/correlations_repository.ex:68  in  list_correlation_jobs/1 Root cause:   list_correlation_jobs/1  (lines 63–70) calls  get_account_id(scope)  which returns nil for a personal-only user, then directly passes nil to  where(account_id: ^account_id) . Unlike  get_latest_completed_job  (which was fixed to check for nil),  list_correlation_jobs  has no nil guard. Fix required:  Add the same nil guard pattern used in  get_latest_completed_job : def list_correlation_jobs(%Scope{} = scope) do
  case get_account_id(scope) do
    nil -> []
    account_id ->
      CorrelationJob
      |> where(account_id: ^account_id)
      |> order_by(desc: :inserted_at)
      |> Repo.all()
  end
end Affected file:   lib/metric_flow/correlations/correlations_repository.ex:63–70

## Source

QA Story 447 — `.code_my_spec/qa/447/result.md`

## Resolution

Added nil guard to list_correlation_jobs/1 in correlations_repository.ex (lines 63-70) using the same case/nil pattern already present in get_latest_completed_job, get_latest_correlation_summary, has_running_job?, and list_correlation_results. When get_account_id/1 returns nil for a personal-only user, the function now returns [] instead of passing nil to the Ecto where clause. File changed: lib/metric_flow/correlations/correlations_repository.ex. Verified by running MIX_ENV=test mix agent_test — no new failures introduced.
