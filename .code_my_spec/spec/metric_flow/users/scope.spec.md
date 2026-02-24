# MetricFlow.Users.Scope

Caller scope struct exported by the Users boundary for use across the application. Holds the current User struct in the user field (nil for unauthenticated callers). Provides a for_user/1 constructor that returns a populated Scope for a given User or nil when passed nil. Consumed as the first parameter of public context functions in all bounded contexts to carry caller identity, enable authorization checks, scope database queries, and support PubSub subscriptions.

## Delegates

None

## Functions

### for_user/1

Creates a Scope struct for a given User, or returns nil for unauthenticated callers.

```elixir
@spec for_user(User.t()) :: t()
@spec for_user(nil) :: nil
```

**Process**:
1. Pattern-match on the argument
2. When a %User{} struct is given, return a new %Scope{} with the user field set to that struct
3. When nil is given, return nil directly

**Test Assertions**:

## Dependencies

- MetricFlow.Users.User

## Fields

| Field | Type              | Required | Description                              | Constraints              |
| ----- | ----------------- | -------- | ---------------------------------------- | ------------------------ |
| user  | User.t() or nil   | No       | The authenticated user for this scope    | Defaults to nil          |
