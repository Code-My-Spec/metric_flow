# MetricFlowWeb.AccountLive.Members

Manage account members and permissions for the active account. Displays all members with their roles and join dates. Owners and admins can change member roles, remove members, and invite new users. Enforces authorization via `Accounts.Authorization` — only owners/admins see management controls. Protects the last owner from removal or demotion. Subscribes to member PubSub for real-time updates.

**Type**: liveview

## Dependencies

- MetricFlow.Accounts

## Delegates

## Functions

### mount/3

Initialize the LiveView by loading members for the active account.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `current_scope` from socket assigns
2. Get the active account via `scope.active_account_id`; redirect to `/accounts` if no active account
3. Load members via `Accounts.list_account_members(scope, account_id)` (returns members with preloaded users)
4. Determine the current user's role via `Accounts.get_user_role(scope, scope.user.id, account_id)`
5. Subscribe to member PubSub via `Accounts.subscribe_member(scope)`
6. Assign `members`, `account_id`, `current_user_role`, and page title

**Test Assertions**:
- renders the members page with account members listed
- displays each member's name, email, role, and join date
- redirects to accounts page when no active account is set
- redirects unauthenticated users to login

### render/1

Render the members list with role management controls.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Render page header with title "Members"
2. For each member, render a row with `data-role="member"` showing: user email, role badge, and `inserted_at` date
3. If current user is owner or admin, show role change dropdown and remove button for each non-self member
4. Hide remove button for the last owner (prevent orphaned account)
5. Include an "Invite Member" section with email input for owners/admins
6. Members with `:member` role see a read-only list without management controls

**Test Assertions**:
- displays member email and role for each member
- shows role change controls for owners/admins
- hides management controls for regular members
- does not show remove button for the last owner
- includes invite member form for owners/admins

### handle_event("change_role", params, socket)/3

Change a member's role within the account.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `user_id` and `role` from params
2. Call `Accounts.update_user_role(scope, user_id, account_id, role)`
3. On success: reload members list, put success flash
4. On error (e.g., last owner demotion): put error flash with message

**Test Assertions**:
- updates member role and reflects change in the list
- prevents demoting the last owner and shows error
- only owners/admins can change roles

### handle_event("remove_member", params, socket)/3

Remove a member from the account.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `user_id` from params
2. Call `Accounts.remove_user_from_account(scope, user_id, account_id)`
3. On success: reload members list, put success flash
4. On error (e.g., last owner): put error flash

**Test Assertions**:
- removes member and they disappear from the list
- prevents removing the last owner and shows error
- only owners/admins can remove members

### handle_event("invite_member", params, socket)/3

Invite a new user to the account by email.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `email` and `role` from params
2. Look up user by email; if not found, put error flash
3. Call `Accounts.add_user_to_account(scope, user_id, account_id, role)`
4. On success: reload members list, put success flash, clear form
5. On error (e.g., already a member): put error flash

**Test Assertions**:
- adds a new member to the account
- shows error when email not found
- shows error when user is already a member
- only owners/admins can invite members

### handle_info(pubsub_message, socket)/2

Handle real-time PubSub updates for member changes.

```elixir
@spec handle_info(tuple(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Pattern match on `{:created, _}`, `{:updated, _}`, or `{:deleted, _}` member messages
2. Reload members list via `Accounts.list_account_members(scope, account_id)`
3. Re-assign updated members to socket

**Test Assertions**:
- refreshes member list when a member is added
- refreshes member list when a member role changes
- refreshes member list when a member is removed
