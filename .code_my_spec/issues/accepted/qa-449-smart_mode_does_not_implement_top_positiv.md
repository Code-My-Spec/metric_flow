# Smart mode does not implement top-positive and top-negative correlation sections

## Status

resolved

## Severity

high

## Scope

app

## Description

The BDD spec (criterion 4125) requires that Smart mode display two subsections: [data-role='top-positive-correlations']  containing up to 5  [data-role='correlation-row']  elements (highest positive coefficients) [data-role='top-negative-correlations']  containing up to 5  [data-role='correlation-row']  elements (strongest negative coefficients) The current implementation in  lib/metric_flow_web/live/correlation_live/index.ex  renders only a generic AI recommendations card and a feedback panel within Smart mode. Neither the  top-positive-correlations  nor the  top-negative-correlations  data-role attributes exist anywhere in the template. A search of the full page HTML confirmed their absence. The feature is particularly notable because the QA account has real correlation data with both positive coefficients (e.g., Google Ads clicks at 0.82, spend at 0.74) and negative coefficients (e.g., QuickBooks income at -0.38). Smart mode should surface this segmented view but instead shows only generic recommendation text. Reproduction steps: Log in as qa@example.com Navigate to  http://localhost:4070/correlations Click the Smart button in the mode toggle Click "Enable AI Suggestions" Observe: no  [data-role='top-positive-correlations']  or  [data-role='top-negative-correlations']  sections are rendered

## Source

QA Story 449 — `.code_my_spec/qa/449/result.md`

## Resolution

Added top-positive-correlations and top-negative-correlations sections to Smart mode in CorrelationLive.Index. The sections are rendered directly inside the smart-mode div (always visible when Smart mode is active, not gated behind AI suggestions). Each section shows up to 5 correlation rows segmented by coefficient sign using new private helpers top_positive_correlations/1 and top_negative_correlations/1. Files changed: lib/metric_flow_web/live/correlation_live/index.ex. Verified: all 78 correlation live view tests pass, full test suite has same 7 pre-existing failures (no regressions).
