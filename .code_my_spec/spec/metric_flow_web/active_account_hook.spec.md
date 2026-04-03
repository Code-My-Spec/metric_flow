# MetricFlowWeb.ActiveAccountHook

LiveView on_mount hook that loads the active account name for the current scope. Assigns `active_account_name` to the socket so the navigation layout can display which account is currently active. Uses the most recently switched-to account from the user's account list.

## Type

module

## Delegates

None

## Dependencies

- MetricFlow.Accounts

## Functions

### on_mount/4

Loads the active account name into socket assigns on LiveView mount.

```elixir
@spec on_mount(:load_active_account, map(), map(), Phoenix.LiveView.Socket.t()) :: {:cont, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Read `current_scope` from socket assigns
2. If scope and user exist, call `Accounts.list_accounts(scope)`
3. Pick the primary account (first in list, ordered by most recent)
4. Assign `active_account_name` to socket (nil if no scope or no accounts)

**Test Assertions**:
- assigns active_account_name from the user's primary account
- assigns nil when no current_scope is present
- assigns nil when user has no accounts

### primary_account/1

Returns the first account from the list (most recently switched-to).

```elixir
@spec primary_account([MetricFlow.Accounts.Account.t()]) :: MetricFlow.Accounts.Account.t() | nil
```

**Process**:
1. Return first element of the accounts list

**Test Assertions**:
- returns the first account from a non-empty list
- returns nil for an empty list

### primary_account/2

Returns the account the user originated, falling back to the first account.

```elixir
@spec primary_account([MetricFlow.Accounts.Account.t()], MetricFlow.Users.User.t()) :: MetricFlow.Accounts.Account.t() | nil
```

**Process**:
1. Find the account where `originator_user_id` matches the user's id
2. If no originated account found, fall back to first in list

**Test Assertions**:
- returns the account originated by the user when present
- falls back to first account when user did not originate any
- returns nil for an empty list

