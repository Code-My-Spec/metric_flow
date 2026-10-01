# Qa Story Brief

Story 20: Create and Save Custom Reports

## Tool

web

## Auth

Log in via the password form at `http://127.0.0.1:59302/users/log-in`:

```lua
browser_delete_cookies({})
browser_navigate({ url = "http://127.0.0.1:59302/users/log-in" })
browser_wait_for_load({})
browser_scroll_into_view({ selector = "#login_form_password" })
browser_fill({ selector = "#password_email", text = "qa@example.com" })
browser_fill({ selector = "#user_password", text = "hello world!" })
browser_click({ selector = "#login_form_password button[name='user[remember_me]']" })
```

## Seeds

`qa@example.com` owns real connected integrations across multiple platforms (marketing + financial via QuickBooks) with real metric data (confirmed by multiple earlier passes this session), sufficient to exercise cross-platform metrics in a report.

## What To Test

- **150/922, 923 — Create from template or blank canvas.** `/app/dashboards/new`: confirm the template chooser shows at least two template cards plus "Blank Canvas". Click a template card, confirm it populates the canvas with that template's visualizations. Separately start fresh and click "Blank Canvas", confirm the canvas clears/starts empty.
- **151/924 — Add a visualization by metric + chart type.** Click "+ Add Visualization", confirm the metric picker (`[data-role='metric-picker']`) opens with a metric list and chart-type selector, select a metric and chart type, click "Add to Dashboard" (`[data-role='confirm-add-btn']`), confirm a new visualization card appears.
- **152/925 — Arrange visualizations in a layout.** With 2+ visualizations added, use the ↑/↓ ("Move up"/"Move down") buttons on a card and confirm the order actually changes. Note: this story's own BDD spex for this criterion checks for `[data-role='drag-handle']` or `[draggable='true']`, neither of which exists — the real implementation uses up/down reorder buttons instead, which still satisfies the criterion's own "(drag and drop **or grid**)" wording. Flag the spex itself as needing a selector fix (qa-scope), not the app.
- **153/926, 154/927 — Name, save, and the report appears in the list.** Fill the Dashboard Name field, click Save, confirm redirect/success and that the new report appears at `/app/dashboards`.
- **155/928 — Edit a saved report.** Open the saved report from the list, confirm it loads in edit mode (`handle_params(%{"id" => id}, ...)`), add/remove/reorder a visualization, re-save, confirm the change persisted.
- **156/929 — Delete a saved report.** From `/app/dashboards`, delete the report created above, confirm it disappears from the list and (ideally) the DB row is gone.
- **157/930 — Metrics from multiple connected platforms.** Add visualizations using metrics from at least two different platforms (e.g. a marketing metric and the QuickBooks financial metric), confirm both render.
- **158/931 — Charts render using Vega-Lite.** Confirm each visualization card's `[data-role='vega-lite-chart']` has a real `data-spec` JSON payload and actually renders (not just a placeholder).
- **159/932 — Canned Vega-Lite spec editor.** Confirmed via `mix test` that this criterion's own spex (932) is currently **failing**: no `[data-role='open-spec-panel']` or `[data-role='spec-panel']` exists anywhere in `DashboardLive.Editor` — there is no raw/canned Vega-Lite JSON spec editing panel in the report editor at all (unlike the separate `VisualizationLive.Editor` used for single visualizations, which does have LLM-driven spec editing per stories 19/29). File as a real app-scope issue if confirmed live.
- **160/933 — Insert a saved visualization from the library.** Confirmed via `mix test` that criterion 933's own spex is currently **failing**: there is no mechanism anywhere in `DashboardLive.Editor` to browse/insert an existing saved `Visualization` record from the library into a report — only the template system and the ad-hoc metric+chart-type picker exist. File as a real app-scope issue if confirmed live.

## Result Path

`.code_my_spec/qa/20/result.md`

## Setup Notes

Two of this story's own spex (932, 933) are currently red going into this pass (confirmed via `mix test test/spex/20_create_and_save_custom_reports/*.exs` — 20/23 passed, pre-dating any change this session made). A third (925) also fails but on a narrower implementation-detail mismatch (buttons vs. drag handles) rather than a missing feature. Results are recorded via `submit_qa_result` plus `create_issue`.

## Results

Used a fresh dashboard (id 9, "QA Story 20 Test Report", deleted again at the end of the pass) to avoid touching any other story's fixtures.

- **150/922, 923**: pass. Template chooser shows Marketing Overview, Financial Summary, and Blank Canvas; selecting Marketing Overview populated 4 real visualization cards.
- **151/924**: pass. Add Visualization opens a real metric-list + chart-type-selector; selecting `revenue` + `bar` and confirming added a 5th card.
- **152/925**: pass on the real criterion intent (live-confirmed Move-up/Move-down genuinely reorders cards), but the criterion's own spex is wrong -- it checks for a drag-handle/draggable attribute that was never built, since the real implementation uses buttons instead. Filed as qa-scope issue `dc633430` (low), not counted against the story.
- **153/926, 154/927**: pass. Naming and saving redirected to the new dashboard's show page and it appeared in `/app/dashboards`.
- **155/928**: pass. Opening `/app/dashboards/9/edit`, adding a 6th visualization, and re-saving persisted (confirmed by reloading the edit page afterward: 6 cards).
- **156/929**: pass. Delete is a real two-step in-page confirmation (`delete` -> `confirming_delete` assign -> `confirm_delete`); clicking through both steps removed it from the list and the DB row was confirmed gone.
- **157/930**: pass. The saved report mixed clicks/spend/impressions/ROAS (marketing) with revenue (financial) in one report.
- **158/931**: pass. Each visualization card's `[data-role='vega-lite-chart']` carries a real, valid Vega-Lite v5 schema spec.
- **159/932**: **fail**. No raw/canned Vega-Lite spec editor panel exists anywhere in this editor -- confirmed live (`specPanelCount=0`) and via the currently-failing spex. Filed as issue `db11efd5` (high).
- **160/933**: **fail**. No mechanism exists to insert a saved visualization from the library into a report -- confirmed live (the only "Library" text on the page is the unrelated nav sidebar link) and via the currently-failing spex. Filed as issue `c1d0854a` (high).

Submitting as **partial** with issues `db11efd5` and `c1d0854a` linked (the qa-scope spex-mismatch issue `dc633430` is informational, not blocking).
