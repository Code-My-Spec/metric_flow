# Design Review

## Overview

This review covers the MetricFlow.Users context and its four child components: User, UserToken, UserNotifier, and Scope. The architecture is sound and well-structured. Three spec inaccuracies were found and corrected before this review was written; no issues remain outstanding.

## Architecture

- Separation of concerns is clean. The context owns all database interactions and orchestration; child modules handle only schema, query-building, email delivery, and the scope struct.
- User is a proper Ecto schema module: it defines fields, changesets, and one utility predicate (valid_password?/2). It does not touch the Repo.
- UserToken is a dual-purpose schema and query-builder module. Build functions return unsaved structs; verify functions return {:ok, Ecto.Query.t()} or :error so callers execute queries against the Repo independently. This keeps database execution out of UserToken.
- UserNotifier is a thin delivery module that composes Swoosh emails and dispatches them through MetricFlow.Mailer. It branches on confirmed_at to select the correct email template; no other logic lives here.
- Scope is a pure struct module with a single constructor. Its only dependency is User, which is appropriate for a first-party scope type.
- The Boundary declaration on the context (`deps: [MetricFlow], exports: [User, Scope]`) is consistent with the context spec's Dependencies section. UserToken and UserNotifier are internal and not exported, which is correct.
- No circular dependencies exist among the child components. User has no dependency on UserToken, UserToken has no dependency on UserNotifier, and Scope depends only on User.

## Integration

- The context calls User.email_changeset/3, User.password_changeset/3, User.confirm_changeset/1, and User.valid_password?/2 directly as wrapper calls, not defdelegate. The spec's "Delegates: None" declaration is accurate.
- UserToken.build_session_token/1 and UserToken.build_email_token/2 return {token, struct} tuples. The context inserts the struct and returns or uses the token. This two-step pattern keeps persistence in the context layer.
- UserToken verify functions return {:ok, Ecto.Query.t()} or :error. The context either pattern-matches directly (login_user_by_magic_link/1 hard-matches {:ok, query}) or uses with (update_user_email/2, get_user_by_magic_link_token/1). This difference in handling is now documented in the login_user_by_magic_link/1 spec.
- UserNotifier.deliver_update_email_instructions/2 and UserNotifier.deliver_login_instructions/2 are called from the context after token insertion; the URL is constructed in the context from the encoded token, keeping URL-generation logic out of the notifier.
- Scope.for_user/1 is not called by the context itself; it is consumed by callers (controllers, live views) to build scope values passed into context functions. This is consistent with the architectural pattern described in the spec.
- MetricFlow.Mailer is a dependency of UserNotifier only; the context does not call the mailer directly.

## Conclusion

The MetricFlow.Users context is ready for implementation. All specs are internally consistent, dependency declarations match the Boundary configuration, and component responsibilities are cleanly separated. Three corrections were made to the context spec during this review (documented in Issues below); no further action is required before writing code.

## Issues

- **register_user/1 Process step referenced email_changeset/2**: The description referred to `User.email_changeset/2` but the function is defined as `email_changeset/3` with a default third argument. Fixed to `email_changeset/3`.

- **sudo_mode?/2 default value mismatch**: The description stated "default 20" but the implementation default is `-20` (a negative integer offset passed to `DateTime.add/3`). Passing a positive value would compute a future threshold and always return false. Fixed the description to state "defaults to -20" and clarified that the argument is a negative offset. The @spec type `integer()` is unchanged, as it correctly accepts negative integers.

- **login_user_by_magic_link/1 error behavior for undecodable tokens**: The process description and test assertion implied the function returns `{:error, :not_found}` for any invalid token. In reality the implementation does a hard pattern match `{:ok, query} = UserToken.verify_magic_link_token_query(token)`, which raises `MatchError` when the token string is not valid base64. Only tokens that decode correctly but are expired or missing return `{:error, :not_found}`. Fixed the process description to note the hard match and updated the test assertions to distinguish between the two failure paths.
