# MetricFlowWeb.AccountLive.Settings

Account settings, ownership transfer, and deletion for the active account. Owners and admins can edit account name and slug. Only owners can transfer ownership to another admin/member and delete the account. Deletion requires typing the account name for confirmation and re-entering the user's password. Personal accounts cannot be deleted. Subscribes to account PubSub for real-time updates.

**Type**: liveview

## Dependencies

- MetricFlow.Accounts
- MetricFlow.Users

## Delegates

## Functions

### mount/3

Initialize the LiveView by loading the active account and determining user permissions.

```elixir
@spec mount(map(), map(), Phoenix.LiveView.Socket.t()) :: {:ok, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `current_scope` from socket assigns
2. Get the active account via `Accounts.get_account!(scope, scope.active_account_id)`; redirect to `/accounts` if no active account
3. Determine the current user's role via `Accounts.get_user_role(scope, scope.user.id, account.id)`
4. Build an account changeset for the settings form via `Accounts.change_account(scope, account)`
5. Subscribe to account PubSub via `Accounts.subscribe_account(scope)`
6. Assign `account`, `current_user_role`, `form`, `delete_form`, and page title

**Test Assertions**:
- renders the account settings page with account name and slug
- redirects to accounts page when no active account is set
- redirects unauthenticated users to login
- shows delete section only for owners

### render/1

Render the account settings form, ownership transfer, and danger zone.

```elixir
@spec render(map()) :: Phoenix.LiveView.Rendered.t()
```

**Process**:
1. Render page header with title "Account Settings"
2. Render settings form with `name` and `slug` fields, pre-filled from account; show save button for owners/admins
3. Display account type as read-only (personal/team)
4. If current user is owner and account is team type:
   - Render "Transfer Ownership" section with member dropdown (`data-role="transfer-ownership"`)
   - Render "Delete Account" danger zone (`data-role="delete-account"`) with confirmation form requiring account name input and password
5. Display a permanent deletion warning in the danger zone
6. Hide destructive sections for non-owner roles

**Test Assertions**:
- displays account name and slug in editable form
- shows account type as read-only
- shows transfer ownership section for owners only
- shows delete account section for owners of team accounts only
- hides delete section for personal accounts
- hides destructive sections for admin and member roles

### handle_event("validate", params, socket)/3

Validate account settings form on change.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract account attributes from params
2. Build changeset via `Accounts.change_account(scope, account, attrs)` with `action: :validate`
3. Assign updated form to socket

**Test Assertions**:
- shows validation errors for invalid slug format
- shows validation errors for slug too short or too long

### handle_event("save", params, socket)/3

Save account settings changes.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract account attributes from params
2. Call `Accounts.update_account(scope, account, attrs)`
3. On success: re-assign updated account, put success flash
4. On error: assign changeset errors to form

**Test Assertions**:
- updates account name and slug successfully
- shows validation errors for invalid input
- only owners/admins can save settings

### handle_event("transfer_ownership", params, socket)/3

Transfer account ownership to another member.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `new_owner_user_id` from params
2. Call `Accounts.update_user_role(scope, new_owner_user_id, account.id, :owner)` to promote the target
3. Call `Accounts.update_user_role(scope, scope.user.id, account.id, :admin)` to demote self to admin
4. Re-assign `current_user_role` and reload account members, put success flash
5. On error: put error flash

**Test Assertions**:
- transfers ownership to selected member and demotes current owner to admin
- only owners can transfer ownership
- updates UI to reflect new role (destructive sections hidden after transfer)

### handle_event("delete_account", params, socket)/3

Delete the account after confirmation.

```elixir
@spec handle_event(String.t(), map(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Extract `confirmation_name` and `password` from params
2. Validate that `confirmation_name` matches the account name exactly
3. Verify user password via `Users.get_user_by_email_and_password(scope.user.email, password)`
4. If both checks pass: call `Accounts.delete_account(scope, account)`, redirect to `/accounts` with info flash
5. If name mismatch: put error flash "Account name does not match"
6. If password wrong: put error flash "Incorrect password"

**Test Assertions**:
- deletes account when name confirmation and password are correct
- rejects deletion when typed name does not match account name
- rejects deletion when password is incorrect
- only owners can delete accounts
- personal accounts cannot be deleted
- redirects to accounts page after successful deletion

### handle_info(pubsub_message, socket)/2

Handle real-time PubSub updates for account changes.

```elixir
@spec handle_info(tuple(), Phoenix.LiveView.Socket.t()) :: {:noreply, Phoenix.LiveView.Socket.t()}
```

**Process**:
1. Pattern match on `{:updated, %Account{}}` messages
2. Re-assign updated account and rebuild form changeset
3. On `{:deleted, _}`: redirect to `/accounts` with info flash

**Test Assertions**:
- refreshes settings when account is updated externally
- redirects when account is deleted externally
