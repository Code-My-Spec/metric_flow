# Evidence — integration-account-edit-design-pass

Four full-page PNGs of `/app/integrations/google/accounts/edit`
captured from this worktree's own dev server against the seeded
Anderson Retail Co. account (owner `client@example.com` from
`priv/repo/seeds.exs`, password `hello world!`). The `:google`
integration seeded on Anderson Retail is the right view to compare:
the page lists the stored `selected_accounts` (none configured — the
placeholder row reads "No accounts configured — connect and sync to
populate"), and both the structural change (plain `<form>` wrapper)
and the token change (`btn-brand-gradient` primary action, card
drawn with DESIGN.md Card tokens) land in one frame at each width.

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page. Container drawn with `mf-card` (an undefined class — no border, no background). The account row sits on a `bg-base-200 rounded` block, no border. The Save button is daisyUI `btn btn-primary`, same weight as the `btn btn-ghost` "Back to integrations" link below it. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop — same invisible card chrome, same flat primary button, same ghost back link. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page. The `data-role="account-selection"` container is now a real `<form phx-submit="save_account_selection">`, drawn with the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200 p-6`). The account row is a `<label>` on `rounded-box border border-neutral bg-base-100`. The Save action is a full-width `btn-brand-gradient rounded-box`, with the "Back to integrations" link below as a DESIGN.md Secondary (`rounded-box border border-neutral bg-base-200`). `document.documentElement.scrollWidth === 390` was read back before the shot. |
| `after-1440.png`  | 1440x900  | after  | Same post-pass markup on desktop: form, Card-tokened panel, brand-gradient primary that is content-sized at `sm:w-auto` while the Secondary sits left of it. |

## Capture environment

- Dev server started from this worktree with
  `PORT=4090 DATABASE_NAME=metric_flow_iae_dp MIX_ENV=dev
  CMS_MAIN_COPY=false sops exec-env envs/dev.enc.env mix phx.server`,
  against a seeded `metric_flow_iae_dp` database (`mix ecto.migrate`
  then `mix run priv/repo/seeds.exs`). `CMS_MAIN_COPY=false` kept the
  worktree's Cloudflare tunnel disabled so the beam stayed on
  `127.0.0.1:4090`.
- `agent-browser` (headless Chromium) drove the login flow (filled
  `client@example.com` / `hello world!` into the `#login_form_password`
  password form and clicked "Log in"), then navigated to
  `/app/integrations/google/accounts/edit`. Before each screenshot the
  driver read back `window.liveSocket && liveSocket.isConnected()`
  (true all four times), `location.pathname`
  (`/app/integrations/google/accounts/edit` all four times), and
  `document.documentElement.scrollWidth` (390 at the 390 viewport,
  1440 at the 1440 viewport).
- The before shots were captured after `git checkout HEAD --` on
  `lib/metric_flow_web/live/integration_live/account_edit.ex`
  (restoring the issue-as-handed-in version at commit `3bcdb344`) and
  letting Phoenix live-reload re-render the old markup —
  `!!document.querySelector('.mf-card')` read back `true` before both
  before shots. The file was restored to the post-pass edit before the
  final commit (grep confirms `mf-card` is gone, `btn-brand-gradient`
  is present).

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/integration_live/account_edit_test.exs`
  passes 11 tests, including the new describe
  `"design pass: a plain form in Anderson BI tokens"` that asserts
  `form[data-role='account-selection']` is present,
  `button[data-role='save-account-selection'].btn-brand-gradient`
  is rendered, and the pre-pass tokens (`mf-card`, the old `rounded`
  row class) are gone. The new test fails against the pre-pass file
  (confirmed by reverting `account_edit.ex` to HEAD and running the
  describe: fails on the `form[data-role='account-selection']`
  assertion).
- `MIX_ENV=test mix test test/spex/13_view_and_manage_platform_integrations/criterion_96_user_can_modify_selected_accounts_without_re-authenticating_spex.exs`
  passes.
