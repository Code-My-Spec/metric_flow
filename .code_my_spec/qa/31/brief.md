# Qa Story Brief

Story 31: Client Views White-labeled Interface

## Tool

curl (plus web for the authenticated-session portions where feasible)

## Auth

Agency account reused from story 30's pass, still live on this checkout: `qa30owner20260930@example.com` / `SecurePassword123!`, owner of "QA30 Agency Owner" (agency-type), with white-label branding already configured: subdomain `qa30claimed20260930`, logo `https://cdn.example.com/logo.png`, primary `#111111`, secondary `#222222` (Pending DNS verification, never verified).

## Seeds

No new seeds needed. The key mechanism this story depends on -- `MetricFlowWeb.Plugs.WhiteLabel` -- resolves branding purely from the *request's Host header* (`conn.host`) via `put_session`, with no DNS/websocket dependency:

```elixir
config = lookup_by_custom_domain(conn.host) || lookup_by_subdomain(conn.host)
```

This means `curl -H "Host: <subdomain>.metric-flow.app" http://127.0.0.1:59302/...` exercises the exact same code path a real DNS-routed request would, without needing to edit system DNS/hosts files (which would be invasive on this shared machine and is not needed here). Cowboy/Plug derive `conn.host` from the literal HTTP Host header, not from actual DNS resolution.

**Critical environment note carried over from story 30:** this worktree's dev server reads database `metric_flow_dev_wc_bd0baac8`. If `/users/log-in` 503s with `Phoenix.Ecto.PendingMigrationError` again, re-run `DATABASE_NAME=metric_flow_dev_wc_bd0baac8 mix ecto.migrate` before assuming a new regression (see issue 61f6b4f9).

## What To Test

- **258/823: client sees agency branding via agency subdomain** -- `curl -s -H "Host: qa30claimed20260930.metric-flow.app" http://127.0.0.1:59302/users/log-in` and inspect the response for the configured logo URL / color values appearing anywhere in the HTML/CSS (e.g. as inline styles, data attributes, or a `<link>`/logo `<img src>`).
- **261/827: default branding via main domain** -- Same request but with `Host: 127.0.0.1:59302` (or no override) -- confirm no reference to `qa30claimed20260930`'s branding values appears.
- **824: unrecognized subdomain falls back to default branding** -- `curl -H "Host: nosuchagency99999.metric-flow.app"` -- confirm the response looks identical to the default-domain case (no error, no stale/wrong branding).
- **259/825, 260/826: agency logo in nav header, color scheme applied throughout** -- These apply to the authenticated app shell (`Layouts.app`), which needs a real logged-in session. Log in via the browser as a client user whose account the agency actually originated (see Setup Notes for how to determine/construct this), then repeat the Host-header check against an authenticated page if the browser tool supports setting request headers; if not, verify via code review of `Layouts.app`'s use of `white_label_config` assigns (from `WhiteLabelHook`) for the logo `<img>` and any CSS custom properties, backed by the passing `criterion_825`/`criterion_826` BDD specs.
- **262/828: white-labeling always applies for an agency-originated client** -- Distinguish an agency that merely has an access grant (`origination_status: :invited`, as granted in story 8/30) from one that *originated* the client account (`origination_status: :originator`). Check `MetricFlow.Agencies` for a fixture/flow that creates an originated relationship, or note if this is only reachable via the registration-time "agency referral" path not otherwise exercised in this QA session, and back it with the passing `criterion_262`/`criterion_828` BDD spex if a live repro isn't practical in the time available.
- **263/829, 264/830: client can still customize dashboards; white-labeling is visual only** -- Verify via code review that `white_label_config` assigns are read-only display data in `Layouts.app` and never gate any `handle_event`/mutation logic in dashboard-editing LiveViews, backed by the passing BDD specs for these criteria.

## Result Path

.code_my_spec/qa/31/screenshots/

## Setup Notes

Results are recorded via `submit_qa_result` (a DB-backed attempt) plus `create_issue` for findings -- there is no `result.md` file; the path above is where screenshot evidence is saved. Given the standard `run_browser_script` tool does not expose a way to set a custom `Host` header for full authenticated LiveView sessions (the WebSocket handshake and all subsequent `Host` values would need to match, which the browser automation layer does not support), the authenticated/interactive criteria (263/829, 264/830) are verified via code review and their own passing BDD specs rather than a live browser repro, while the host-resolution mechanism itself (258/823, 259/825, 260/826, 261/827, 824, 262/828) is confirmed with direct `curl` requests carrying a fresh per-host session cookie and exercising the real plug/hook/layout code path end-to-end.

## Results

All live testing was done via `curl` with `-H "Host: ..."` against `http://127.0.0.1:59302`, using a fresh login (fresh CSRF token, fresh cookie jar) per host, since session cookies here have no `Domain` attribute and are therefore host-only -- reusing one host's cookie under a different `Host` header correctly redirects to login rather than leaking a session across hosts, which is itself a sound security property (not a bug) and is why each scenario below re-authenticates.

Agency used: `qa30owner20260930@example.com` (reused from story 30), with white-label config eventually set to logo `https://cdn.example.com/logo.png`, primary `#111111`, secondary `#222222`, subdomain `qa30claimed20260930` marked verified directly via SQL for this pass (it was left unverified/Pending at the end of story 30 -- verifying it is what this pass needed to test the activated state; a future pass reusing this same agency should be aware it's now verified, unlike story 30's brief assumed).

- **258/823, 261/827, 824: agency subdomain shows branding, main domain shows default, unrecognized subdomain falls back to default** -- pass. `curl -H "Host: qa30claimed20260930.metric-flow.app" .../app/dashboard` (verified subdomain) returned `data-white-label="true"`, `--wl-primary: #111111;`, `--wl-secondary: #222222;`, and the logo `<img>`. The identical authenticated request with no Host override, and again with `Host: nosuchagency99999.metric-flow.app`, both returned zero white-label markers -- exactly the default/fallback state, confirming `Plugs.WhiteLabel`'s verified-subdomain-only lookup (`AgenciesRepository.get_white_label_config_by_subdomain/1` filters on `not is_nil(subdomain_verified_at)`) works correctly end-to-end.
- **259/825, 260/826: agency logo in nav header, color scheme applied throughout** -- pass. Confirmed in the same verified-subdomain response: two `<img data-role="agency-logo">` elements (desktop + mobile nav) with the configured `src`, and `--wl-primary`/`--wl-secondary` CSS custom properties set in an inline `<style>` block covering the whole layout shell.
- **262/828: white-labeling always applies for an agency-originated client** -- pass. Both BDD specs (`criterion_262`, `criterion_828`) test exactly the same host-based subdomain resolution already confirmed live above, granted via `grant_agency_originator_access` rather than a plain access grant; `Plugs.WhiteLabel` has no reference to `origination_status` anywhere in its resolution logic (confirmed via full source read), so origination status governs other things (e.g. whether the grant can be revoked) but not branding resolution itself -- the same mechanism applies uniformly regardless of how access was granted, which is consistent with "always applied" and doesn't need a separate live repro of the specific originator fixture.
- **263/829: client can still customize their own dashboards regardless of white-labeling** -- pass (code-review-backed). `white_label_config` is a read-only display assign consumed only by `Layouts.app`/`Layouts.app_public`; no dashboard-editing LiveView (`DashboardLive.Editor`, `VisualizationLive.Editor`) references it in any `handle_event` or mutation path.
- **264/830: white-label branding changes appearance only, not functionality** -- pass (code-review-backed). Same basis as above -- `white_label_config` never appears in any authorization check, route guard, or business-logic branch across the codebase; it is purely a rendering input to `Layouts`.

No issues found for this story.
