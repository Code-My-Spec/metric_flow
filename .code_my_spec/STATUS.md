# Metric Flow — status, 2026-09-30

Dev project: `5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c` · repo:
`/Volumes/X10 Pro/github/metric_flow` (permanent home)

## Where things stand

- Onboarded; working copies are live (main + `three-features`), preview
  tunnel up at the harness-served preview URL.
- DevOps is on: UAT and prod are deployed, secrets migrated off the earlier
  AWS SSM path. No infrastructure blockers remain.
- Requirement graph is live; `get_next_requirement` / `start_task` /
  `evaluate_task` is the normal loop across coding/product/QA/main roles.
- QA has real history in `.code_my_spec/qa/`; `list_issues` is the current
  source of truth for open findings (see `HANDOFF.md` for what matters now).

## Four legs

See `HANDOFF.md` — that's the front line now; this file doesn't duplicate it.

## What's next

Route remaining unbuilt-feature gaps (agency white-label, agency
auto-enrollment, paywall) through the normal story pipeline: product →
spec → code → promote → QA, same as everything else. No special handling
needed.
