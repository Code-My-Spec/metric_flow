# Design Review

## Overview

Reviewed the MetricFlow.Ai context and its 8 child components: AiRepository (module), ChatMessage (schema), ChatSession (schema), Insight (schema), SuggestionFeedback (schema), InsightsGenerator (module stub), LlmClient (module stub), and ReportGenerator (module stub). The architecture is sound overall — schemas, repository, and orchestration responsibilities are cleanly separated and the context correctly acts as the sole public API boundary. Three issues were found and fixed before writing this review.

## Architecture

- Separation of concerns is clean: schemas (Insight, ChatSession, ChatMessage, SuggestionFeedback) carry only field definitions and changeset logic; AiRepository owns all database access; LlmClient centralises all ReqLLM calls; InsightsGenerator and ReportGenerator encapsulate prompt assembly and response parsing.
- The schema helper functions (Insight.actionable?/1, Insight.high_confidence?/1, SuggestionFeedback.helpful?/1, ChatSession.archive_changeset/1) are well-placed — they are pure computations over struct state that belong on the schema, not the context.
- AiRepository follows the standard repository pattern: all queries accept Scope, all writes return `{:ok, struct}` or `{:error, Ecto.Changeset.t()}`, and the upsert_feedback/3 function correctly uses on_conflict to implement the rating-update semantics.
- InsightsGenerator, LlmClient, and ReportGenerator are stubs (module name and type only, no functions). This is expected — these modules were not in the component spec phase and will be fleshed out during implementation. The context spec's Components section and the architecture overview carry enough description for implementation guidance.
- The declared dependency on MetricFlow.Dashboards is not exercised by any current context function. It is declared in the architecture for future use (dashboard-scoped chat sessions may eventually query dashboard metadata). No change made; this should be implemented when a function that calls MetricFlow.Dashboards is added.

## Integration

- Context delegates list_insights/2, get_insight/2, list_chat_sessions/1, get_chat_session/2, and get_feedback_for_insight/2 to AiRepository. All five functions exist in the AiRepository spec with matching signatures.
- generate_insights/2 calls MetricFlow.Correlations.get_correlation_job/2 and MetricFlow.Correlations.list_correlation_results/2, then AiRepository.create_insight/2 for persistence. Both Correlations context functions exist in correlations.spec.md.
- generate_vega_spec/2 calls MetricFlow.Metrics.list_metric_names/2. This function exists in the Metrics context spec with arity 2 (Scope + keyword opts).
- submit_feedback/3 calls AiRepository.get_insight/2 for authorization then delegates to AiRepository.upsert_feedback/3. Both exist in AiRepository spec.
- create_chat_session/2 and send_chat_message/3 delegate to AiRepository.create_chat_session/2 and AiRepository.create_chat_message/2 respectively. Both exist in AiRepository spec.
- LlmClient is used by InsightsGenerator (generate_insights/2) and ReportGenerator (generate_vega_spec/2) and directly by the context's send_chat_message/3 streaming task. This is consistent with the component descriptions.
- ChatSession.archive_changeset/1 is available for archiving sessions but no context-level archive function is defined. This is not a blocking gap — the AiRepository.update_chat_session/3 function can accept the result of archive_changeset/1, and a future context function can be added when the UI requires it.

## Issues

- **Fixed**: generate_insights/2 Process step 1 referenced "CorrelationsRepository" directly, bypassing the context boundary. Changed to `MetricFlow.Correlations.get_correlation_job/2` to respect context encapsulation. Similarly, step 8 now explicitly names `AiRepository.create_insight/2`.
- **Fixed**: generate_vega_spec/2 Process step 1 called `MetricFlow.Metrics.list_metric_names/1` with arity 1. The Metrics context defines this function as `list_metric_names/2` (Scope plus keyword options). Corrected to `list_metric_names/2`.
- **Fixed**: create_chat_session/2 Process described calling `Repo.insert` directly, bypassing AiRepository entirely despite AiRepository.create_chat_session/2 existing for exactly this purpose. Process rewritten to delegate to AiRepository.create_chat_session/2, consistent with all other write operations in the context.
- **Fixed**: submit_feedback/3 Process steps 3–5 described building the SuggestionFeedback changeset and executing the upsert inside the context function. This duplicates logic that belongs in AiRepository.upsert_feedback/3. Process rewritten to delegate to AiRepository.upsert_feedback/3 after the authorization check, consistent with the repository pattern used everywhere else.

## Conclusion

The MetricFlow.Ai context is ready for implementation. All four issues found during review have been fixed in the spec files. The three stub modules (InsightsGenerator, LlmClient, ReportGenerator) have sufficient description in the context spec's Components section to guide implementation without a separate component spec phase. No blocking gaps remain.
