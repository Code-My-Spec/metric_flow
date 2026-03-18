# "Logged out successfully." flash never displayed after logout

## Status

resolved

## Severity

medium

## Scope

app

## Description

When a user logs out via the "Log out" link,  UserSessionController.delete/2  calls
 put_flash(:info, "Logged out successfully.")  and then  UserAuth.log_out_user/1  which
redirects to  ~p"/"  (the home page). The home page is rendered by  PageController.home/2  using the  root.html.heex  layout.
Neither  root.html.heex  nor  home.html.heex  includes flash rendering (no  <.flash_group> ,
 <.flash> , or any flash display component). The flash message is stored in the session cookie
but is never rendered to the user. This means users receive no confirmation feedback when logging out — a usability issue that
could cause confusion about whether the logout action was successful. Reproduced consistently: log in as  qa@example.com , navigate to  /users/settings , click
"Log out". The browser redirects to  /  but no "Logged out successfully." message appears. Fix options: Add  <.flash_group flash={@flash} />  to  root.html.heex  so flash works on all controller routes Redirect logout to a LiveView route (e.g.  /users/log-in ) that renders flash correctly Add flash rendering to the  home.html.heex  template

## Source

QA Story 425 — `.code_my_spec/qa/425/result.md`

## Resolution

Changed `UserAuth.log_out_user/1` to redirect to `/users/log-in` instead of `/` after logout. The `/users/log-in` route is a LiveView that uses `Layouts.app`, which already renders `<.flash_group flash={@flash} />`. This ensures the "Logged out successfully." flash message is displayed to the user after logout.

Adding `<.flash_group>` directly to `root.html.heex` was considered but rejected because it would create duplicate flash IDs (`client-error`, `server-error`) when LiveViews that embed `Layouts.app` (which already includes `flash_group`) are rendered within the root layout.

### Files changed

- `lib/metric_flow_web/user_auth.ex` — Changed redirect in `log_out_user/1` from `~p"/"` to `~p"/users/log-in"`
- `test/metric_flow_web/user_auth_test.exs` — Updated logout redirect assertions to expect `/users/log-in`
- `test/metric_flow_web/controllers/user_session_controller_test.exs` — Updated logout redirect assertions to expect `/users/log-in`

### Verification

All 2561 tests pass, including the specific logout redirect tests in `UserAuthTest` and `UserSessionControllerTest`.
