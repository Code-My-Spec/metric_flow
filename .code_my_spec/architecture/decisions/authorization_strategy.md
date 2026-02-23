# Authorization Strategy

## Status

Accepted

## Context

MetricFlow is a multi-tenant Phoenix 1.8 SaaS with role-based access control (owner, admin, member)
across business accounts. The application was generated with `mix phx.gen.auth`, which provides:

- `MetricFlow.Users.Scope` struct carrying `user`, `active_account`, and `active_account_id`
- Scope-based function signatures throughout all contexts
- `MetricFlow.Accounts.Authorization` module with hand-rolled role checks

The authorization requirements are straightforward:

- **Owner**: Full account control (delete, transfer ownership, manage members and settings)
- **Admin**: Manage members, edit account settings
- **Member**: Read access to account resources (dashboards, integrations, metrics)
- **Agency access**: Agencies manage client accounts through the same role model

## Decision

**Use the built-in `phx.gen.auth` Scope pattern with the existing hand-rolled
`Accounts.Authorization` module. No external authorization library is adopted.**

The current approach is sufficient because:

1. The role hierarchy is simple (owner > admin > member) with no complex permission
   combinations or attribute-based rules.
2. Authorization checks live in context functions, not in LiveViews or controllers,
   so they are tested through context-level unit tests.
3. The `Scope` struct already carries all authorization context needed for every call.
4. Adding a DSL library (LetMe, Bodyguard, Permit) would add abstraction without reducing
   code — the `Authorization` module is ~30 lines and directly expresses the business rules.

## Consequences

- Authorization rules are maintained in `MetricFlow.Accounts.Authorization` as pattern-matched
  `{action, resource}` tuples. New actions are added by extending the case clause.
- Context functions call `Authorization.authorize/3` or `Authorization.authorize!/3` with the
  scope and resource before performing privileged operations.
- If authorization requirements grow significantly (e.g., per-resource field-level permissions,
  agency delegation chains), revisit this decision and evaluate LetMe or Bodyguard.
- No new dependencies added.
