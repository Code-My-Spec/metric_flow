<!-- cms:task type="TriageIssues" component="medium" -->

# Triage Issues

You are triaging incoming QA issues at **medium+** severity.

## Goal

Produce a clean `accepted/` folder with real, deduplicated issues. Your job:

1. **Read all incoming issues** listed below
2. **Identify duplicates** — issues describing the same underlying problem
3. **Decide a disposition** for each issue:
   - **Accept** — real issue, move to `.code_my_spec/issues/accepted/`
   - **Dismiss** — not a real bug (test artifact, expected behavior, duplicate), move to `.code_my_spec/issues/dismissed/`
   - **Merge** — consolidate evidence from duplicates into one accepted issue, dismiss the others
4. **Execute** — move files using `Write` to the target directory and delete from `incoming/`

Each issue may have a `## Scope` section (`app`, `qa`, or `docs`). Preserve the scope
when moving files. If an issue is missing a scope section, default to `app`.

When merging duplicates: pick the best title, consolidate description and evidence into
one accepted issue file, and dismiss the rest with a note about which issue they merged into.

Ensure the `accepted/` and `dismissed/` directories exist before writing (create them if needed).

## Incoming Issues

## High (4)

### `qa-431-accountlive_index_does_not_display_agency.md`

```markdown
# AccountLive.Index does not display agency access level or origination status badges

## Severity

high

## Scope

app

## Description

The  /accounts  page renders all accounts the user is a member of but shows only a hardcoded "Owner" badge and the user's own email as "Originator" for every card. The implementation does not call  MetricFlow.Agencies  context functions, does not distinguish between own accounts and client accounts accessed via agency grants, and does not render access level badges ("Admin", "Account Manager", "Read Only") or origination status badges ("Originator", "Invited"). All accounts the user is an AccountMember of appear identically regardless of their actual role or relationship type. Criteria 3992 and 3999 fail entirely. Reproduction: Log in as  qa@example.com , navigate to  http://localhost:4070/accounts . Observe "Client Alpha" (agency admin, originator) and "Client Beta" (agency admin, invited) are displayed identically. Source:  lib/metric_flow_web/live/account_live/index.ex

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```

### `qa-431-accountlive_index_missing_switch_account_.md`

```markdown
# AccountLive.Index missing switch-account controls and data-role attributes

## Severity

high

## Scope

app

## Description

The accounts page has no  [data-role="switch-account"]  elements, no  phx-click="switch_account"  event handler, no  data-role="account-card"  attributes on cards, and no  data-active  attribute on cards. The account context switching feature (criterion 3993) is entirely absent. The spec at  .code_my_spec/spec/metric_flow_web/account_live/index.spec.md  documents these as required: each account card should have  data-role="account-card"  and a  [data-role="switch-account"]  button. None of these are implemented. Reproduction: Log in, navigate to  /accounts . Inspect DOM — no  data-role  attributes on account cards.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```

### `qa-431-navigation_missing_current_account_name_i.md`

```markdown
# Navigation missing current-account-name indicator

## Severity

high

## Scope

app

## Description

No  [data-role="current-account-name"]  element exists in the navigation on any authenticated page ( /accounts ,  /accounts/settings ,  /integrations ). The spec requires the nav to clearly display which account is currently active. The navigation bar contains only the logo, nav links, theme toggle, and user avatar — no account context indicator. Criterion 3994 fails entirely. Reproduction: Log in, navigate to any authenticated page. Inspect DOM for  [data-role="current-account-name"]  — not found.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```

### `qa-431-read_only_and_account_manager_users_can_s.md`

```markdown
# Read-only and account_manager users can see the full members list

## Severity

high

## Scope

app

## Description

Users with  read_only  or  account_manager  roles on a client account can navigate to  /accounts/members  and see the complete list of all member emails, roles, and join dates. Per criterion 3998, only users with admin access should see the members list. qa-431-readonly@example.com  (read_only on "Client Read Only"): members list fully visible with 5 member records including emails. qa-431-acctmgr@example.com  (account_manager on "Client Account Manager"): members list fully visible with 5 member records. Additionally, none of the member rows or the members list container have  data-role="members-list"  or  data-role="member-row"  attributes, so even if role-gating were added, the BDD spec selectors would still fail. Reproduction: Log in as  qa-431-readonly@example.com  /  hello world! , navigate to  http://localhost:4070/accounts/members . Full member list is visible. Evidence:  .code_my_spec/qa/431/screenshots/06-members-readonly-user.png

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```

## Medium (2)

### `qa-431-active_account_defaults_to_most_recently_.md`

```markdown
# Active account defaults to most-recently-joined account instead of primary account

## Severity

medium

## Scope

app

## Description

When  qa@example.com  (the agency owner) logs in, their "active" account resolves to "Client Account Manager" — the most recently created client account — rather than their own "QA Test Account". This is because  Accounts.list_accounts/1  orders by  account_members.inserted_at DESC , and the grant propagation step added qa@example.com as a member of the client accounts most recently. The account settings page shows "Client Account Manager" as the active account for the owner, and the owner has no edit form there (they have account_manager role on that account). The owner cannot easily access their own account's settings. This is a systemic issue: without an explicit account-switching mechanism (criterion 3993), users with multiple account memberships are stuck with whatever account the list ordering puts first. Reproduction: Run both seed scripts, log in as  qa@example.com , navigate to  /accounts/settings . Observe "Client Account Manager" shown as active instead of "QA Test Account". Evidence:  .code_my_spec/qa/431/screenshots/02-accounts-settings-owner.png

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```

### `qa-431-members_list_and_member_rows_missing_data.md`

```markdown
# Members list and member rows missing data-role attributes

## Severity

medium

## Scope

app

## Description

The  AccountLive.Members  page renders the members list and member rows without  data-role="members-list"  or  data-role="member-row"  attributes. The BDD specs for criteria 3997 and 3998 assert the presence or absence of these selectors. Even for the admin user (where the members list IS correctly shown), the selectors  [data-role='members-list']  and  [data-role='member-row']  return false because the attributes do not exist in the rendered HTML. Reproduction: Log in as  qa-431-admin@example.com  /  hello world! , navigate to  /accounts/members . Inspect DOM — no  data-role  attributes on member list container or rows.

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```

## Directories

- Incoming: `.code_my_spec/issues/incoming/`
- Accepted: `.code_my_spec/issues/accepted/`
- Dismissed: `.code_my_spec/issues/dismissed/`

Stop the session when all issues have been triaged.
