# App layout does not render agency logo or color scheme from white_label_config

## Severity

high

## Scope

app

## Description

MetricFlowWeb.Layouts.app/1  accepts  white_label_config  as an attr and several LiveViews pass it, but the layout function body never uses it. The navbar renders only hardcoded "MetricFlow" text. There is no conditional rendering of an agency logo image ( logo_url ), no CSS custom property injection for  primary_color / secondary_color , and no  data-white-label ,  data-agency-logo , or  data-agency-colors  attributes anywhere in the output HTML. Fix: the layout's  app/1  function needs to conditionally render the agency logo in the navbar when  @white_label_config  is non-nil, and inject agency colors as CSS custom properties (e.g., via an inline  <style>  tag or  style  attribute on a wrapper element).

## Source

QA Story 454 — `.code_my_spec/qa/454/result.md`

## Resolution

Updated `MetricFlowWeb.Layouts.app/1` to:
- Inject a `<style>` block with CSS custom properties (`--wl-primary`, `--wl-secondary`) when `@white_label_config` is non-nil
- Conditionally render an agency logo `<img>` in the navbar when `logo_url` is present, replacing hardcoded "MetricFlow" text
- Fall back to default "MetricFlow" text when no white-label config exists

**Files changed:** `lib/metric_flow_web/components/layouts.ex`
**Verified:** `mix test` — all account and dashboard tests pass (116/116).
