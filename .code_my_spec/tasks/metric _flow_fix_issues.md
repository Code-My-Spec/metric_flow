# Fix Issues

You are fixing accepted QA issues at **medium+** severity.

## Tools

Use the following bash tools in `.code_my_spec/tools/issues/` to interact with issues:

- `.code_my_spec/tools/issues/get-issue <id>` — read full issue details
- `.code_my_spec/tools/issues/resolve-issue <id> "<resolution>"` — mark as resolved with description of fix

## Goal

For each issue below:

1. **Understand the problem** — read the issue description and source QA result
2. **Fix the code** — use subagents (Agent tool) for the actual fix work. Group related issues
   into one subagent if they share a root cause. Each subagent should:
   - Read the relevant source files
   - Make the fix
   - Verify the fix works
3. **Resolve the issue** — run `.code_my_spec/tools/issues/resolve-issue <id> "<resolution>"` with a summary of:
   - What was fixed
   - Files changed
   - How the fix was verified
4. **Run tests** after all fixes to verify nothing is broken: `mix test`

## Scope-Aware Fixing

Issues have a scope indicating what to fix:
- **app** — Fix application code (controllers, live views, schemas, etc.)
- **qa** — Fix QA infrastructure (seed scripts, auth scripts, QA plan, test tooling)
- **docs** — Fix documentation (specs, README, user stories)

Read the scope before fixing — a `qa` issue means the seeds or scripts need updating, not the app code.

## QA Context

- **QA plan:** `.code_my_spec/qa/plan.md` — server startup, seeds, auth strategy
- **QA results:** `.code_my_spec/qa/{story_id}/` — failed results, screenshots, briefs

Read the QA plan for how to start the server and run seeds if you need to verify fixes.
Read the failed result and screenshots for each issue's story to understand the reproduction.

## Unresolved Issues

## Scope: app (3)

### `qa-520-missing_location_flagging_not_implemented.md` (ID: 89a75a3f-74b4-41b8-b9b1-d8006f2e0a43)

**Source:** `.code_my_spec/qa/520/result.md`
**QA evidence:** `.code_my_spec/qa/520/`
- **Title:** Missing-location flagging not implemented (criterion 4862)
- **Severity:** high
- **Scope:** app
- **Story:** 520

When a previously configured location ID is no longer returned by the GBP API (e.g., a deleted or revoked location), the accounts page shows no warning, flag, or indicator. The manual entry field is pre-filled with the old location ID with no UI feedback that it may be invalid. The acceptance criterion requires the system to flag missing/unavailable locations rather than silently pre-filling the stale ID. Reproduced by setting  included_locations  to  ["accounts/123/locations/deleted-loc-1"]  in the integration's  provider_metadata , then navigating to  /integrations/connect/google_business/accounts . The field shows the stale ID with no warning. This requires the GBP API fetch to return results in order to compare configured locations against live ones. The feature is blocked until  list_google_business_locations  returns data.

### `qa-520-location_row_data_role_attributes_missing.md` (ID: 1910f142-6df3-4693-b23b-c387587087c8)

**Source:** `.code_my_spec/qa/520/result.md`
**QA evidence:** `.code_my_spec/qa/520/`
- **Title:** Location row data-role attributes missing from template (criteria 4855–4856)
- **Severity:** medium
- **Scope:** app
- **Story:** 520

The  render_account_selection/1  template in  connect.ex  uses generic field bindings ( property.name ,  property.account ,  property.id ) in  data-role="account-option"  items. The acceptance criteria specify distinct  data-role  attributes for GBP-specific location fields:  data-role="location-title" ,  data-role="location-address" ,  data-role="location-store-code" , and  data-role="location-account-name" . These attributes are absent from the current template, meaning automated tests based on the acceptance criteria selectors will fail when location data is available.

### `qa-520-save_account_selection_saves_included_loc.md` (ID: 89408cce-c215-47d5-b920-4cd10278fc34)

**Source:** `.code_my_spec/qa/520/result.md`
**QA evidence:** `.code_my_spec/qa/520/`
- **Title:** save_account_selection saves included_locations as a string instead of an array
- **Severity:** medium
- **Scope:** app
- **Story:** 520

The  save_account_selection  handler in  connect.ex  saves the manual entry text as a single string to the  included_locations  key (via  metadata_key_for_provider(:google_business)  returning  "included_locations" ). The acceptance criteria describe  included_locations  as an array of location IDs to support multi-location selection. When the metadata is externally set to a JSON array and then loaded by the LiveView,  get_in(integration.provider_metadata, ["included_locations"])  returns the array, which is passed to  @manual_property_id . The form's  value  attribute then receives a list. After saving via the UI, the array is overwritten with a single string. For multi-location selection (described in the acceptance criteria), the save handler must collect and store an array of IDs rather than a single string.

## Directory

Accepted issues: `.code_my_spec/issues/accepted/`

Fix the issues, resolve them with the tool, and run tests to verify.
