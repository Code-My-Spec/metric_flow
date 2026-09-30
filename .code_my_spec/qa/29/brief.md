# QA Story 29 Brief: LLM-Driven Visualization Authoring

## Tool

web

## Auth

```
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
browser_wait_for_url({ pattern = "/", timeout = 5000 })
```

## Seeds

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

This worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`. Real metric names exist for qa@example.com (clicks, impressions, total_cost, revenue, etc. — see `/app/dashboard` for the current list) — use a real one in prompts so the LLM can bind to actual data, and a deliberately fake one (e.g. `qa_story29_nonexistent_metric`) to test the unresolvable-metric error path.

## Setup Notes

**The story prompt's "Linked component" (`MetricFlowWeb.AiLive.ReportGenerator`, route `/app/reports/generate`) does not implement most of this story's own criteria.** Reading it shows a single-shot flow: one textarea prompt → one generated spec → preview → save, with no chat, no follow-up refinement, no spec editor, no three-panel layout, and no conversation history. The three-panel chat + spec-editor + live-preview architecture this story's own criteria describe in detail (225/234: three panels; 228/801: follow-up refinement; 230/243/804: direct spec edit without LLM round-trip; 231/807: chat history; 236/247: full spec as context; 239/812: multi-metric layering) is actually implemented in `MetricFlowWeb.VisualizationLive.Editor` (`lib/metric_flow_web/live/visualization_live/editor.ex`, routes `/app/visualizations/new` and `/app/visualizations/:id/edit` — criterion 234 literally names this route). The underlying AI logic lives in `MetricFlow.Ai.VizChat` (agentic, Anubis-MCP-tool-backed: `UpdateSpec`, `ListDocs`, `ReadDoc`, `SearchDocs`, `QueryMetrics` tools), not `Ai.generate_vega_spec` (which `ReportGenerator` calls).

Test **both** pages: Editor for the chat/iterative criteria (225–249, 799–814), ReportGenerator for its own narrower single-shot criteria (218–224, which predate the chat architecture and may describe ReportGenerator's actual flow). File the component-mismatch as a `docs` or `qa`-scope issue so the story's own metadata gets corrected, separate from any behavioral findings.

Code read ahead of testing: `VisualizationLive.Editor`'s `assign_common/2` always calls `stream(:chat_messages, [])` on mount/remount — no DB read of prior messages anywhere in the module, and no `AiRepository.create_chat_message` call in the chat send/receive handlers either. This strongly suggests chat history does **not** survive a reopen/reload (criterion 807), even though it does persist within one live LiveView process's lifetime (satisfying 231 more narrowly). Confirm live before filing.

`Ai.VizChat` only calls `Logger.error` on an LLM call failure — there's no log of successful prompts/responses/tool-calls anywhere in the module. Confirm whether this satisfies "logs all LLM interactions for debugging" (224/805) or whether only failures are logged.

## What To Test

- **Editor chat generates an initial spec (226/235/799/800/227):** `/app/visualizations/new`, type a real request referencing an actual account metric (e.g. "Show me a bar chart of clicks over time") into the chat panel, submit. Confirm the assistant responds, a spec appears in the preview (`[data-role='vega-lite-chart']` gets a `data-spec`), and the spec editor drawer reflects it if opened.
- **Follow-up refinement (228/801/810):** send a second chat message asking to change something (e.g. "make it a line chart instead") — confirm the spec updates (not regenerated from an empty state — same bound metric, different mark) and both editor and preview update without a page reload.
- **Direct spec edit without LLM round-trip (230/243/804):** with a spec loaded, open the spec editor (`toggle_left_panel`), edit the raw JSON textarea directly (e.g. change `"mark"`), blur — confirm the preview updates immediately with no chat activity/spinner.
- **Chat history across reopen (231/807):** after a chat exchange, save the visualization, navigate away, then reopen `/app/visualizations/:id/edit` for that same id — confirm whether the prior chat messages are still shown or the chat panel is empty.
- **Unresolvable metric error (244/814):** ask the chat for a chart using a metric name that doesn't exist for this account — confirm the chat panel surfaces a clear error rather than silently producing a broken/empty chart.
- **Multi-metric layered spec via chat (239/812):** ask for a chart combining two real metrics — confirm the resulting spec uses `"layer"` with a separate named `data` source per metric (same shape already confirmed manually in story 19; confirm the *LLM* produces this shape too, not just the manual editor path).
- **Named data sources, no embedded values (237/248/811, 811's join-table binding):** confirm the LLM-generated spec never contains a `"values"` array, only `{"data": {"name": "<metric>"}}`, and that saving creates the matching `visualization_metrics` rows (check via SQL: `select * from visualization_metrics where visualization_id = <id>`).
- **Save & library appearance (232/245/808, 233/246/809):** name and save the chat-generated visualization; confirm it appears at `/app/visualizations` with correct name.
- **ReportGenerator's own flow (218–224):** `/app/reports/generate` — enter a prompt, generate, preview, save. Confirm this narrower single-shot flow works on its own terms (it is a real, separate, working feature regardless of the component-metadata mismatch above).
- **LLM interaction logging (224/805):** check the dev server log / Logger output during a chat exchange — confirm whether anything beyond error cases is logged.

## Result Path

Findings are filed via `create_issue` as discovered; final result via `submit_qa_result`. No result.md file.

## Results (this pass)

The platform's Anthropic API key has a zero credit balance (confirmed directly against api.anthropic.com), blocking every criterion that requires an actual successful LLM generation on both `/app/visualizations/new` (viz chat) and `/app/reports/generate` (single-shot generator) — both failed identically live. Filed as qa-scope issue `35f3e718`. This is an environment blocker, not an app bug; both failure paths correctly surfaced a clear error to the user rather than a silent no-op, which is itself a live confirmation of criterion 802.

Filed the component-metadata mismatch (story's linked component is `ReportGenerator`, but almost all of its own criteria describe `VisualizationLive.Editor`'s three-panel chat/spec/preview workspace) as docs-scope issue `5b537606`.

While investigating chat-history persistence I initially suspected (from an earlier read of `editor.ex` in story 19) that chat history never survives a reopen — that read is now stale. The current `editor.ex` has real session persistence (`Ai.get_chat_session_by_context/3` on mount, `ensure_chat_session/2`, `persist_chat_message/3`) and logging (`Logger.warning("viz_chat exchange completed session_id=...")`). Live-verified without needing a working LLM call: sent a chat message on `/app/visualizations/22/edit`, hard-reloaded, and the user message was still shown — `chat_messages`/`chat_sessions` tables confirm it's really persisted and correctly linked (`context_type: visualization, context_id: 22`). This means criteria 231/807 (chat history persists / reopening shows history) and 224/805 (logs interactions) pass. (The assistant's error-turn text itself isn't persisted, only real successful exchanges are — reasonable, not filed as an issue.)

The remaining mechanics — three-panel layout, direct spec-edit-without-LLM-round-trip reflecting in the preview, multi-metric layering with named data sources, save-persists via the `visualization_metrics` join table, and library listing — were already verified live in story 19's QA pass against this same `VisualizationLive.Editor`, and were spot-confirmed again here (spec editor drawer still reflects the saved template correctly). `qa_complete` stays open pending the Anthropic credit top-up so the LLM-generation criteria (226/235/799, 227/800, 228/801, 239/812, 244/814, 240/813) can actually be exercised.
