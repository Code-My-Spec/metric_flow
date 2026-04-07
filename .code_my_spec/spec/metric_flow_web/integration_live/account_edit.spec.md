# MetricFlowWeb.IntegrationLive.AccountEdit

Edit which ad accounts or properties are synced for a connected integration without re-authenticating via OAuth. Loads the existing integration's selected accounts from provider_metadata and presents them as checkboxes. The user toggles selections and saves.

## Type

liveview

## Route

`/integrations/:provider/accounts/edit`

## Params

- `provider` - string, provider key (e.g., `google_ads`, `facebook_ads`, `google_analytics`, `quickbooks`). Converted to atom via `String.to_existing_atom/1`; unknown atoms redirect to `/integrations`.

## Dependencies

- MetricFlow.Integrations

## Components

None

## User Interactions

- **phx-click="save_account_selection"**: Flashes "Account selection saved." and navigates to `/integrations`.

## Design

Layout: Centered single-column page, `max-w-lg mx-auto`, `.mf-content` wrapper with `px-4 py-8` padding.

Page header:
- H1 "{platform name} — Edit Accounts" in `text-2xl font-bold`
- Subtitle "Choose which accounts or properties to sync." in `text-base-content/60`

Account selection card (`data-role="account-selection"`, `.mf-card p-6`):
- Stack of account rows (`space-y-3`), each with `bg-base-200 rounded p-3`:
  - `.checkbox.checkbox-sm` with `data-role="account-checkbox"`, checked when the account is selected
  - Account label text in `text-sm`
- When no accounts are configured, a single placeholder row with unchecked checkbox and label "No accounts configured — connect and sync to populate"

Form actions (`mt-6 flex flex-col gap-2`):
- `.btn.btn-primary.w-full` "Save Selection" button with `data-role="save-account-selection"` and `phx-click="save_account_selection"`
- `.btn.btn-ghost.btn-sm` "Back to integrations" link navigating to `/integrations`

On mount: no-op (data loading in handle_params). On handle_params: converts provider string to atom, fetches integration via `Integrations.get_integration(scope, provider)`, extracts selected accounts from `provider_metadata["selected_accounts"]`, builds display accounts list. Redirects to `/integrations` for unknown provider atoms.

Components: `.mf-card`, `.checkbox`, `.btn`, `.btn-primary`, `.btn-ghost`

Responsive: Single-column layout stacks naturally on all screen sizes.
