# "Welcome back!" flash not shown after password login

## Status

resolved

## Severity

medium

## Scope

app

## Description

After a successful password login,  UserSessionController#create  sets a  put_flash(:info, "Welcome back!")  before calling  UserAuth.log_in_user/3 , which redirects to  / . However, the home page ( / ) is rendered by  PageController#home  using  page_html/home.html.heex  as a template within  root.html.heex . The root layout does not include  <.flash_group flash={@flash} />  — only  Layouts.app  (used by LiveViews) includes flash rendering. As a result, the "Welcome back!" flash is set in the session but silently discarded — it is never rendered on the home page. Users have no confirmation that their login succeeded. Reproduced: log in with  qa@example.com  /  hello world!  — the home page loads with no flash message. Root cause:  root.html.heex  lacks  <.flash_group> . Either the root layout needs to include flash rendering, or the post-login redirect should go to a LiveView page that uses  Layouts.app .

## Source

QA Story 425 — `.code_my_spec/qa/425/result.md`

## Resolution

Changed `signed_in_path/1` in `MetricFlowWeb.UserAuth` to redirect new logins to `/integrations` instead of `/`. The `/integrations` route is a LiveView that uses `Layouts.app`, which already includes `<.flash_group flash={@flash} />`. This ensures the "Welcome back!" flash message is visible after a successful password or magic link login.

Adding `<.flash_group>` directly to `root.html.heex` was attempted first but caused duplicate DOM IDs (`client-error`, `server-error`) for all LiveView pages, which embed `Layouts.app` (with its own `<.flash_group>`) inside the root layout's `{@inner_content}`.

**Files changed:**
- `lib/metric_flow_web/user_auth.ex` — `signed_in_path/1` default clause now returns `~p"/integrations"` instead of `~p"/"`
- `test/metric_flow_web/user_auth_test.exs` — updated redirect assertion from `"/"` to `"/integrations"`
- `test/metric_flow_web/controllers/user_session_controller_test.exs` — updated redirect assertions (4 occurrences)
- `test/metric_flow_web/live/user_live/login_test.exs` — updated redirect assertion
- `test/metric_flow_web/live/user_live/registration_test.exs` — updated `follow_redirect` path

**Verified:** All 2561 tests pass with `mix test`.
