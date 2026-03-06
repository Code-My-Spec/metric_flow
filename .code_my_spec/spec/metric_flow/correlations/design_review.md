# Design Review

## Overview

Reviewed the MetricFlow.Correlations context (1 context + 5 child components: CorrelationJob, CorrelationResult, CorrelationsRepository, CorrelationWorker, Math). The architecture is sound — clean separation between pure computation (Math), persistence (CorrelationsRepository, schemas), job orchestration (CorrelationWorker), and the public context API. Several spec inconsistencies were found and fixed during review.

## Architecture

- **Separation of concerns is clean**: Math handles pure computation with no database or process dependencies; CorrelationsRepository handles all persistence; CorrelationWorker orchestrates the background job lifecycle; the context provides the public API boundary.
- **Component types are appropriate**: CorrelationJob and CorrelationResult are schemas; CorrelationsRepository is a data access module; CorrelationWorker is an Oban worker; Math is a pure functional module.
- **Dependency direction is correct**: Context → Repository, Context → Metrics (external), Worker → Math, Worker → Repository, Worker → Metrics. No circular dependencies.
- **Scope-first security applied consistently**: All public context functions accept Scope.t() as first parameter. Repository functions scope queries by account_id.
- **schedule_daily_correlations/0 is the only function without Scope**: This is correct — it's a system-level cron job that processes all qualifying accounts.

## Integration

- **Context delegates 4 functions to CorrelationsRepository**: list_correlation_results/2, get_correlation_result/2, get_correlation_job/2, list_correlation_jobs/1 — all verified to exist in CorrelationsRepository spec.
- **Context → CorrelationsRepository**: run_correlations/2 uses has_running_job?/1, create_correlation_job/2. get_latest_correlation_summary/1 uses get_latest_completed_job/1 and list_correlation_results/2.
- **CorrelationWorker → Math**: Worker calls extract_values/2, cross_correlate/3 for each metric pair.
- **CorrelationWorker → CorrelationsRepository**: Worker calls get_correlation_job/2, update_correlation_job/3, create_correlation_result/2.
- **CorrelationWorker → MetricFlow.Metrics**: Worker calls list_metric_names/1 and query_time_series/3 (external dependency).
- **CorrelationResult → CorrelationJob**: belongs_to relationship via correlation_job_id.

## Issues

- **Fixed: CorrelationsRepository was a stub** — Fleshed out with 9 functions matching all delegation targets and worker needs.
- **Fixed: CorrelationWorker was a stub** — Fleshed out perform/1 with full process description and test assertions.
- **Fixed: Context spec used `goal_metric_id`** — Changed to `goal_metric_name` throughout to match CorrelationJob and CorrelationResult schema fields (string-based, not FK-based).
- **Fixed: Context Components section referenced `p_value`** — Removed; CorrelationResult schema doesn't include p_value. Pearson significance testing is out of scope for the initial pure-Elixir implementation.
- **Fixed: Context Components section referenced `extract_values/1`** — Changed to `extract_values/2` to match Math spec (takes two series as input).

## Conclusion

The Correlations context is ready for implementation. All specs are internally consistent, delegates map to real repository functions, component boundaries are clean, and the dependency graph has no cycles. Implementation should proceed in dependency order: Math → schemas (CorrelationJob, CorrelationResult) → CorrelationsRepository → CorrelationWorker → Correlations context.
