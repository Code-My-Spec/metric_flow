# AI streaming fails in QA environment — "The AI encountered an error. Please try again."

## Severity

high

## Scope

app

## Disposition

Dismissed — merged into `qa-451-start_qa_sh_does_not_source_uat_env_ai_ke.md`. The root cause is a QA infrastructure gap (missing ANTHROPIC_API_KEY), not an app bug. The app code works correctly when the API key is present.

## Source

QA Story 451 — `.code_my_spec/qa/451/result.md`
