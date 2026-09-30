# QA Story Brief — Story 2: User Login and Session Management

## Tool

web

## Auth

Seeded owner: qa@example.com / hello world! (from priv/repo/qa_seeds.exs). Login form is at /users/log-in, password form has id `login_form_password`.

```
browser_navigate(url: "http://127.0.0.1:59302/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/", timeout: 5000)
```

## Seeds

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Only if qa@example.com login fails — seeds are idempotent.

## What To Test

- Valid login: qa@example.com / hello world! via the password form redirects to the signed-in path (criteria 9, 523).
- Invalid login: correct email with a wrong password shows the generic "Invalid email or password" flash — confirm it does not reveal whether the email itself was recognized (criteria 10, 524). `UserSessionController` already returns this exact message for both unknown-email and wrong-password cases (code review), so this is a straightforward live confirmation.
- Logout: while on an arbitrary authenticated page (not just the dashboard), trigger logout (nav "Log out" link posts to the session delete route) and confirm the response redirects to a logged-out state with a "Logged out successfully." flash (criteria 12, 526).
- Session persists across tabs: open a second browser page/tab reusing the same cookie/storage context after logging in and confirm it's also authenticated (criteria 11, 525).
- Remember me: submitting via the "Log in and stay logged in" button sets `remember_me=true`; confirm (via `browser_get_cookies`) that the `_metric_flow_web_user_remember_me` cookie is set, vs. absent when using "Log in only this time" (criteria 6, 14, 528). Actually waiting out the 14-day token expiry live is impractical — verified by code review of `UserToken` (`@session_validity_in_days 14`) and `UserAuth` (`@max_cookie_age_in_days 14`), which is the standard phx.gen.auth reference mechanism.
- Inactive session expiry (criteria 5, 13, 527): verified via code review only — session tokens expire 14 days after creation (`UserToken.by_token_and_context_query` filters `inserted_at > ago(14, "day")`), which is a reasonable, standard interpretation of this criterion; not practical to wait out live in a QA session.

## Result Path

.code_my_spec/qa/2/result.md (not read by the harness — findings go through create_issue/submit_qa_result only)
