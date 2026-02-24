# Design Review

## Overview

Reviewed the MetricFlow.Accounts context spec and 4 child component descriptions (Account, AccountMember, AccountRepository, Authorization). The architecture is sound — clean separation of concerns between schema, repository, and authorization layers with consistent Scope-first security across all 14 public functions.

## Architecture

- **Separation of concerns** is well-defined: schemas (Account, AccountMember) own validation, AccountRepository owns data access and transactions, Authorization owns role-based permission checks, and the context module is a thin delegation layer with PubSub subscriptions.
- **Scope-first security** is consistently applied across all public functions. Database queries join through account_members to enforce multi-tenant isolation.
- **Role hierarchy** (owner > admin > account_manager > read_only) is clearly specified with appropriate guards: last-owner protection, hierarchical promotion limits, and originator immutability.
- **Authorization boundary**: The Authorization module queries membership counts internally for last-owner protection. The context functions (`update_user_role/4`, `remove_user_from_account/3`) also perform last-owner checks in their Process steps. During implementation, the last-owner check should live in one place — recommend placing it in the repository/context layer (as a data integrity guard) and keeping Authorization focused on role-hierarchy permission checks only.
- **PubSub topics** are user-scoped (`accounts:user:#{user_id}`, `account_members:user:#{user_id}`), which correctly supports multi-tenant isolation. The context module owns subscription while the repository broadcasts after mutations.
- **No external context dependencies** — correct per architecture. The Scope struct is passed in by callers from the Users boundary; no import or direct dependency on MetricFlow.Users is needed.
- **`change_account/2` and `change_account/3`** are correctly not delegated to the repository — they call `Account.changeset/2` directly, following the Phoenix pattern where changeset helpers live on the schema.

## Integration

- **Context to Repository**: 10 functions delegated to AccountRepository, covering all CRUD operations for both Account and AccountMember entities.
- **Context to Schema**: `change_account/2` and `change_account/3` call `Account.changeset/2` directly for form-driving changesets.
- **Context to Authorization**: `update_account/3`, `delete_account/2`, `update_user_role/4`, `remove_user_from_account/3`, and `add_user_to_account/4` call `Authorization.can?/3` before proceeding.
- **Context to PubSub**: `subscribe_account/1` and `subscribe_member/1` subscribe to user-scoped topics. Repository broadcasts events after successful mutations.
- **LiveView consumers**: The API surface matches all function calls referenced in AccountLive.Index, AccountLive.Members, and AccountLive.Settings specs.

## Issues

- **Fixed**: `list_account_members/2` assertion "returns an empty list for an account with no members" contradicted the scope check (calling user must be a member, so list is never empty for a valid call). Changed to "returns at least the calling user when they are the only member" and "raises when the calling user is not a member of the account".
- **Fixed**: `update_user_role/4` assertion "prevents an admin from promoting a member to admin when the calling user is account_manager" was misleading — account_managers are fully unauthorized for any role updates. Simplified to "prevents an admin from promoting a member to admin" to test the admin-specific hierarchy limit.

## Conclusion

The Accounts context design is ready for implementation. The API surface is complete for all consuming LiveViews, the authorization model is well-defined, and the component responsibilities are clearly separated. During implementation, consolidate the last-owner check into the repository layer and keep Authorization as a pure role-hierarchy predicate.
