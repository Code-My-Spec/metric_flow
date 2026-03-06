# Design Review

## Overview

Reviewed MetricFlow.Agencies context and its 3 child components: AgenciesRepository, AutoEnrollmentRule, and WhiteLabelConfig. The architecture is sound after resolving type inconsistencies and arity mismatches found during review. The context follows established project patterns with clean separation between schema validation, data access, and business logic.

## Architecture

- **Separation of concerns is well-defined**: Schemas (AutoEnrollmentRule, WhiteLabelConfig) handle validation via changesets, AgenciesRepository handles all database operations, and the Agencies context orchestrates business logic with authorization checks.
- **Repository pattern is consistent**: AgenciesRepository provides CRUD for all agency-specific entities and manages the access grant join table for agency-client relationships. All queries are scoped by account IDs.
- **Scope pattern is correctly applied**: All public context functions accept `Scope.t()` as the first parameter, matching project conventions. Repository functions receive unwrapped integer IDs from the context layer.
- **Delegation pattern is correct**: 4 delegates properly map context /2 functions (Scope + account_id) to repository /1 functions (account_id only), with the context unwrapping the Scope.
- **Dependencies are valid**: Context depends on MetricFlow.Accounts (for Account and Member schemas), MetricFlow.Users (for User struct in auto-enrollment), and MetricFlow.Infrastructure (for Repo). All exist in the architecture.
- **Access grant model is well-structured**: The agency-client relationship uses upsert semantics with conflict targets, supporting both originator and invited access patterns with proper revocation guards.

## Integration

- **Context → Repository**: All context functions delegate to or call AgenciesRepository for data access. Business logic (authorization, access propagation, originator guards) lives in the context.
- **Schemas → Repository**: AutoEnrollmentRule and WhiteLabelConfig provide `changeset/2` used by repository create/update/upsert functions.
- **Auto-enrollment flow**: `process_new_user_auto_enrollment/1` accepts a User struct, extracts the email domain, queries `find_matching_rule/1` in the repository, and creates memberships via `add_agency_team_member/3` — clean data flow with no circular dependencies.
- **Member reuse**: Uses `MetricFlow.Accounts.Member` for team membership rather than creating a separate agency member schema — avoids duplication and keeps membership logic centralized.
- **Access propagation**: Adding/removing team members and granting/revoking client access are coordinated in the context layer to maintain consistency between agency-level and member-level permissions.

## Issues

- **agency_id type was binary_id, should be integer**: Both AutoEnrollmentRule and WhiteLabelConfig specs originally declared `agency_id` as `binary_id`. Account uses default Ecto integer primary keys. Fixed to `integer` in both schema specs.
- **Account ID parameters used String.t() instead of integer()**: Multiple repository and context function specs used `String.t()` for account ID parameters. Fixed all to `integer()` across both specs.
- **process_new_user_auto_enrollment had extraneous arity**: Originally specified as `/2` with an unnecessary second parameter. The function only needs the User struct to extract the email domain. Fixed to `/1`.
- **find_matching_rule had extraneous arity**: Originally specified as `/2` when it only needs the email domain string. Fixed to `/1`.
- **Delegate arities were inconsistent**: Context delegates referenced incorrect arities for child functions. Verified and corrected all 4 delegate entries to properly map context `/2` to repository `/1`.

## Conclusion

The Agencies context is ready for implementation. All type inconsistencies have been resolved, function arities are correct, delegates match child APIs, dependencies are valid, and there are no contradictions in test assertions. The architecture cleanly separates concerns across schema, repository, and context layers following established project patterns.
