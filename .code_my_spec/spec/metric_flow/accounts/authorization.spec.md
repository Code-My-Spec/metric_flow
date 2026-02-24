# MetricFlow.Accounts.Authorization

Role-based authorization module providing can?/3 predicate functions for all account operations. Accepts a Scope struct, an action atom, and a context map containing the account_id and optionally a target_role. Encodes the role hierarchy: owner > admin > account_manager > read_only. Looks up the calling user's role from the database, then evaluates permissions based on that role and the requested action. Returns false for any user who is not a member of the account.

## Delegates

None.

## Functions

### can?/3

Returns true if the calling user has permission to perform the given action in the given account, false otherwise. Looks up the caller's current role from the database via AccountMember, then applies the role-hierarchy permission rules for the requested action. For actions that involve assigning a role to another user (:add_member, :update_user_role), also validates that the caller is not attempting to assign a role above their own level.

```elixir
@spec can?(Scope.t(), atom(), map()) :: boolean()
```

**Process**:
1. Extract user_id from scope.user
2. Extract account_id from the context map
3. Query AccountMember for a record matching user_id and account_id using MetricFlow.Repo
4. Return false immediately if no membership record is found (user is not a member of the account)
5. Extract the caller's role from the membership record
6. Evaluate the action against the caller's role using the permission matrix:
   - :update_account — allow :owner and :admin; deny :account_manager and :read_only
   - :delete_account — allow :owner only; deny all others
   - :add_member — allow :owner and :admin, subject to target_role check (see step 7); deny :account_manager and :read_only
   - :remove_member — allow :owner and :admin; deny :account_manager and :read_only
   - :update_user_role — allow :owner and :admin, subject to target_role check (see step 7); deny :account_manager and :read_only
7. For :add_member and :update_user_role, if a :target_role is present in the context map, verify the target role does not exceed the caller's own role level (owners may assign any role; admins may assign :admin, :account_manager, or :read_only but NOT :owner)
8. Return true if all checks pass, false otherwise
9. Return false for any unrecognised action atom

**Test Assertions**:
- returns true for owner performing :update_account
- returns true for admin performing :update_account
- returns false for account_manager performing :update_account
- returns false for read_only performing :update_account
- returns true for owner performing :delete_account
- returns false for admin performing :delete_account
- returns false for account_manager performing :delete_account
- returns false for read_only performing :delete_account
- returns true for owner performing :add_member with any target_role
- returns true for admin performing :add_member with target_role :admin
- returns true for admin performing :add_member with target_role :account_manager
- returns true for admin performing :add_member with target_role :read_only
- returns false for admin performing :add_member with target_role :owner
- returns false for account_manager performing :add_member
- returns false for read_only performing :add_member
- returns true for owner performing :remove_member
- returns true for admin performing :remove_member
- returns false for account_manager performing :remove_member
- returns false for read_only performing :remove_member
- returns true for owner performing :update_user_role with any target_role
- returns true for admin performing :update_user_role with target_role :admin
- returns true for admin performing :update_user_role with target_role :account_manager
- returns true for admin performing :update_user_role with target_role :read_only
- returns false for admin performing :update_user_role with target_role :owner
- returns false for account_manager performing :update_user_role
- returns false for read_only performing :update_user_role
- returns false when the calling user is not a member of the account
- returns false for an unrecognised action atom
- returns false when scope.user is nil

## Dependencies

- MetricFlow.Accounts.AccountMember
- MetricFlow.Repo
