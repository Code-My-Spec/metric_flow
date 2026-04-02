# MetricFlowWeb.IntegrationLive.AccountEdit

Edit which ad accounts or properties are synced for a connected integration without re-authenticating via OAuth. Loads the existing integration's selected accounts from provider_metadata and presents them as checkboxes. The user toggles selections and saves.

## Type

module

## Delegates

None

## Dependencies

- MetricFlow.Integrations

## Functions

### mount/3

Standard LiveView mount. No-op — data loading happens in handle_params.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Return socket as-is

**Test Assertions**:
- mounts successfully for authenticated user

### handle_params/3

Loads the integration and its selected accounts for the given provider.

```elixir
@spec handle_params(map(), String.t(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Convert provider string to atom
2. Fetch integration via `Integrations.get_integration(scope, provider)`
3. Extract selected accounts from integration's `provider_metadata["selected_accounts"]`
4. Build display accounts list (each with id, label, selected flag)
5. If no accounts configured, show placeholder checkbox
6. Assign display_accounts, platform_name, page_title to socket
7. If provider atom doesn't exist, redirect to `/integrations`

**Test Assertions**:
- renders edit page with platform name heading for valid provider
- displays checkboxes for each selected account
- shows placeholder when no accounts are configured
- redirects to integrations for unknown provider

### handle_event/3 ("save_account_selection")

Saves the account selection and redirects to integrations index.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Flash "Account selection saved."
2. Navigate to `/integrations`

**Test Assertions**:
- flashes success message and redirects to integrations

### render/1

Renders the account edit form with checkboxes and save button.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Render platform name heading and description
2. Render account checkboxes from `@display_accounts`
3. Render save button with `data-role="save-account-selection"`
4. Render back link to `/integrations`

**Test Assertions**:
- renders account checkboxes with data-role attribute
- renders save button
- renders back link to integrations
