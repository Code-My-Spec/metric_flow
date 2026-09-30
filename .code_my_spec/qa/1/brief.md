# QA Story Brief — Story 1: User Registration and Account Creation

## Tool

web

## Auth

N/A for registration itself (unauthenticated flow). For confirming a new user, use the dev mailbox at http://127.0.0.1:59302/dev/mailbox to retrieve the magic-link confirmation email and click through it.

## Seeds

No seeds required for the registration flow itself — it creates fresh users. Use unique emails per scenario (e.g. `qa-reg-<timestamp>@example.com`) since registration is a one-shot, consumable action per email address.

```
mix run --no-start -e "Application.ensure_all_started(:postgrex); Application.ensure_all_started(:ecto); MetricFlow.Repo.start_link([])" priv/repo/qa_seeds.exs
```

Only needed if other stories' seeded accounts are required for cross-checks (not expected here).

## What To Test

- Navigate to `/users/register`, submit with a fresh valid email/password/account name, account type = Agency. Expect the account to actually be created as an **agency** account — verify directly against the DB (`MetricFlow.Repo.get_by(MetricFlow.Accounts.Account, name: "<account_name>")` and check `.type`), since `AccountRepository.create_team_account/2` hardcodes `"type" => :client` in the merged attrs and `UserLive.Registration.maybe_create_account/1` never passes `account_type` through at all — this looks like a real bug from code review and needs live confirmation.
- Same flow with account type = Client, confirm account type is `:client` (this direction should work since it matches the hardcoded default).
- After submitting valid registration, observe what the LiveView actually does: current code (`registration.ex` `handle_event("save", ...)`) sets `registered: true` and renders a "Registration successful" / "check your email" screen — it does **not** call any login/session function or redirect. This appears to contradict criteria 6 and 520 ("after registration user is logged in and directed to onboarding"). Confirm live whether the user ends up logged in and on `/onboarding`, or on the static success screen while logged out.
- Blank email/password: confirm validation errors show (criteria 7, 521).
- Weak password (<12 chars): confirm rejected with clear error.
- Duplicate email: register once, then attempt to register again with the same email — confirm a clear "already in use" style error (criteria 8, 522). Note: the story's own `change_user_registration` call passes `validate_unique: false` during live validation, so uniqueness may only be enforced on final submit — check both.
- Account name field: confirm it's prompted during registration and, when non-blank, an account is actually created with that name (criteria 3, 516).
- Blank account name: per `maybe_create_account/1`, no account is created at all when `account_name` is nil/"" — confirm this is intended (a user can register without any account) rather than a bug, and note it either way.
- Email confirmation: use `/dev/mailbox` to find the magic-link email sent via `deliver_login_instructions/2`, click it, confirm the user becomes logged in and `confirmed_at` gets set (criteria 2, 514, 515).
- After confirming via magic link, verify the user becomes the account's owner (`account_members` role `:owner`) if an account was created (criteria 5, 519).

## Result Path

.code_my_spec/qa/1/result.md (not read by the harness — findings go through create_issue/submit_qa_result only)
