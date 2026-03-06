<!-- cms:task type="FixIssues" component="medium" -->

# Fix Issues

You are fixing accepted QA issues at **medium+** severity.

## Goal

For each issue below:

1. **Understand the problem** — read the issue description and source QA result
2. **Fix the code** — use subagents (Agent tool) for the actual fix work. Group related issues
   into one subagent if they share a root cause. Each subagent should:
   - Read the relevant source files
   - Make the fix
   - Verify the fix works
3. **Add a `## Resolution` section** to each issue file describing what was done:
   - Summary of the fix
   - Files changed
   - How the fix was verified
4. **Run tests** after all fixes to verify nothing is broken: `mix test`

## Scope-Aware Fixing

Issues have a `## Scope` section indicating what to fix:
- **app** — Fix application code (controllers, live views, schemas, etc.)
- **qa** — Fix QA infrastructure (seed scripts, auth scripts, QA plan, test tooling)
- **docs** — Fix documentation (specs, README, user stories)

Read the scope before fixing — a `qa` issue means the seeds or scripts need updating, not the app code.

## QA Results

Issue source references point to QA result files in `.code_my_spec/qa/`. Read those
files for additional context, reproduction steps, and screenshots.

## Unresolved Issues

## Scope: app (5)

### `qa-431-accountlive_index_does_not_display_agency.md`

**Source:** QA Story 431 — `.code_my_spec/qa/431/result.md`

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

**Source:** QA Story 431 — `.code_my_spec/qa/431/result.md`

```markdown
# AccountLive.Index missing switch-account controls and data-role attributes

## Severity

high

## Scope

app

## Description

The accounts page has no  [data-role="switch-account"]  elements, no  phx-click="switch_account"  event handler, no  data-role="account-card"  attributes on cards, and no  data-active  attribute on cards. The account context switching feature (criterion 3993) is entirely absent. The spec at  .code_my_spec/spec/metric_flow_web/account_live/index.spec.md  documents these as required: each account card should have  data-role="account-card"  and a  [data-role="switch-account"]  button. None of these are implemented. Reproduction: Log in, navigate to  /accounts . Inspect DOM — no  data-role  attributes on account cards.

Additionally, without an explicit account-switching mechanism, users with multiple account memberships are stuck with whatever account the list ordering puts first. When qa@example.com (the agency owner) logs in, their "active" account resolves to "Client Account Manager" (the most recently created client account) rather than their own "QA Test Account", because Accounts.list_accounts/1 orders by account_members.inserted_at DESC. The owner cannot easily access their own account's settings.

(Merged from: qa-431-active_account_defaults_to_most_recently_.md)

## Source

QA Story 431 — `.code_my_spec/qa/431/result.md`

```


### `qa-431-navigation_missing_current_account_name_i.md`

**Source:** QA Story 431 — `.code_my_spec/qa/431/result.md`

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

**Source:** QA Story 431 — `.code_my_spec/qa/431/result.md`

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


### `qa-431-members_list_and_member_rows_missing_data.md`

**Source:** QA Story 431 — `.code_my_spec/qa/431/result.md`

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


## Directory

Accepted issues: `.code_my_spec/issues/accepted/`

Fix the issues, add resolution sections, and run tests to verify.
