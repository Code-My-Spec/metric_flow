# QA Result — Story 10: Transfer Account Ownership

Result: **partial** — 13 scenarios, 2 issues filed.

## Passed

- **66/894/895** — Non-owner (`qa-member@example.com`) sees no Transfer Ownership or Delete Account card at `/app/accounts/settings`. Owner sees the `#transfer-ownership-form` card.
- **67/896** — Transfer to an existing member (DB-confirmed, owner→member, `confirmed_at` set).
- **67/897** — Transfer via invite to a new email: fresh end-to-end run (owner→`qa10-remainadmin-20261001@example.com`), pending banner named the target correctly, real confirmation email delivered with a working `/account_transfers/:token` link.
- **68/898** — Before confirmation, role unchanged: owner stayed `owner` while the transfer was `pending`.
- **69/899** — Both `make_copy` and `remain_admin` checkboxes present in `#transfer-ownership-form`, independently toggleable.
- **70/900** — Logged-out visit to the token link shows "Sign in or create an account to confirm this transfer." with Log In / Create an Account buttons, not an Accept button.
- **70/901** — Logged in as the wrong user and clicking Accept correctly produces "This transfer was not sent to your account." with no role change. (Minor cosmetic note: the Accept button itself renders regardless of identity; only the server-side check enforces the rule — not a security issue since the server does reject it, but a coder could tighten the render condition.)
- **71/902** — Acceptance by the correct, authenticated target redirects to `/app/accounts/settings` with flash "You are now the owner of this account." Confirmed on multiple transfers this session.
- **72/903** — Both branches confirmed live: `remain_admin=true` → previous owner becomes `admin`; `remain_admin=false` → previous owner becomes `account_manager` (confirmed on separate fresh transfers).
- **75/906** — `[data-role='ownership-transfer-log-entry']` shows "Ownership transferred from {prev} to {new}, confirmed {timestamp}." after acceptance.

## Failed / Gaps

- **73/904** (issue `15ba831d`, medium) — The transfer wizard's originator checkbox (`[data-role='transfer-originator-checkbox']`) never renders for an account whose own `accounts.type` isn't literally `'agency'`, even when that account has a real origination grant in `agency_client_access_grants`. Confirmed live: "QA Test Account" (type=`client`) genuinely originates "Client Alpha" via a real grant, yet the settings page never shows the checkbox because `account_has_originator_grants?/2` short-circuits on `type != :agency` before checking the grants table. The dedicated spex pass only because their fixture builds an account explicitly typed `:agency`.
- **74/905** (issue `e5b06d20`, medium) — Completion emails after a transfer only reach the two transfer parties, not "all users" as the criterion's own title states. Live repro: "QA Test Account" has 10 real members; two separate completed transfers each produced exactly 2 new mailbox emails (both transfer parties), zero to the other 8 members.

## Environment notes

- This checkout's app required cookie-injection (via a direct curl POST login + `browser_set_cookie`) partway through, after several browser-driven `#login_form_password` submits appeared to silently fail. Root cause turned out to be my own use of wrong parameter names (`value`/`script` instead of the tool's real `text`/`expression`) in earlier `browser_fill`/`browser_evaluate` calls, not a real app or framework bug — once corrected, normal `browser_click` worked reliably for the rest of the session (confirmed via DB state after each action, since some LiveView in-place updates don't trigger `wait_for_load`).
- Login credentials (`qa@example.com` / `hello world!`) and the DB state were otherwise exactly as expected; no environment blockers beyond the above self-correction.
