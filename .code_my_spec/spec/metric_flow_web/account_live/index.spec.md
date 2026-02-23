# MetricFlowWeb.AccountLive.Index

List user's accounts with switcher functionality. Displays all accounts the user belongs to (personal and team), shows account type and the user's role in each, and allows switching the active account context via `UserPreferences.select_active_account/2`. The active account is highlighted. Subscribes to PubSub for real-time account and member updates.

**Type**: liveview

## Dependencies

- MetricFlow.Accounts
- MetricFlow.UserPreferences

## Functions

### mount/3

Initialize the LiveView by loading the user's accounts and subscribing to PubSub topics.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `current_scope` from socket assigns
2. Subscribe to account and member PubSub channels via `Accounts.subscribe_account/1` and `Accounts.subscribe_member/1`
3. Load all user accounts via `Accounts.list_accounts(scope)`
4. Assign `accounts`, `active_account_id` (from `scope.active_account_id`), and page title

**Test Assertions**:
- renders the accounts page with page title
- lists all accounts the user belongs to
- highlights the currently active account
- redirects unauthenticated users to login

### handle_event("switch_account", params, socket)/3

Switch the user's active account context.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `account_id` from params
2. Call `UserPreferences.select_active_account(scope, account_id)` to persist the selection
3. Update `active_account_id` in socket assigns
4. Put an info flash confirming the switch

**Test Assertions**:
- updates the active account and highlights the newly selected account
- persists the selection via UserPreferences
- displays a confirmation flash message

### handle_event("create_team", params, socket)/3

Create a new team account from the inline form.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract account attributes (name, slug) from params
2. Call `Accounts.create_team_account(scope, attrs)`
3. On success: reload accounts list, put success flash, clear form
4. On error: assign changeset errors to form

**Test Assertions**:
- creates a team account and adds it to the list
- shows validation errors for invalid input
- new team account appears in the accounts list

### handle_info(pubsub_message, socket)/2

Handle real-time PubSub updates for account and member changes.

```elixir
@spec handle_info(tuple(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Pattern match on `{:created, _}`, `{:updated, _}`, or `{:deleted, _}` messages
2. Reload accounts list via `Accounts.list_accounts(scope)`
3. Re-assign updated accounts to socket

**Test Assertions**:
- refreshes the account list when a new account is created
- refreshes the account list when an account is updated
- refreshes the account list when an account is deleted

### render/1

Render the accounts list with switcher UI.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Render page header with title "Accounts"
2. For each account, render a card showing: account name, type badge (personal/team), user's role, and active indicator
3. Each account card has a `data-role="account"` attribute and a click handler for `switch_account`
4. The active account card has a `data-active="true"` attribute
5. Include a "New Team Account" form with name and slug fields

**Test Assertions**:
- displays account name for each account
- displays account type badge (personal or team)
- displays the user's role in each account
- active account has a visual indicator
- includes a form to create a new team account
