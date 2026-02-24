# MetricFlow.Users.UserToken

Ecto schema and query-builder module for user authentication tokens. Stores tokens in the "users_tokens" table and supports three distinct contexts: "session" (raw binary, stored unhashed, valid 14 days), "login" (URL-safe base64-encoded SHA-256 hash, valid 15 minutes, for magic-link authentication), and "change:" prefixed contexts (URL-safe base64-encoded SHA-256 hash, valid 7 days, for email address changes). Hashed tokens are never stored in plain text, ensuring database read-only access cannot be leveraged to hijack a session. Each verify function returns an `{:ok, query}` tuple so callers can execute the query against the Repo independently.

## Delegates

(none)

## Functions

### build_session_token/1

Generates a cryptographically random session token and returns a tuple of the raw binary token and an unsaved UserToken struct. The token is stored as-is (not hashed) because it is only transmitted through a signed session cookie.

```elixir
@spec build_session_token(User.t()) :: {binary(), UserToken.t()}
```

**Process**:
1. Generate 32 random bytes using `:crypto.strong_rand_bytes/1`
2. Resolve authenticated_at from `user.authenticated_at` if present, otherwise use `DateTime.utc_now(:second)`
3. Return a two-element tuple: the raw binary token and a UserToken struct with context "session", the given user_id, and the resolved authenticated_at

**Test Assertions**:
(none)

### verify_session_token_query/1

Builds an Ecto query that looks up the user associated with a raw session token, enforcing a 14-day expiry window.

```elixir
@spec verify_session_token_query(binary()) :: {:ok, Ecto.Query.t()}
```

**Process**:
1. Build a base query filtering UserToken by the given binary token and context "session"
2. Join the associated User record
3. Add a where clause requiring `inserted_at` to be within the last 14 days
4. Select a tuple of `{user_with_authenticated_at, token.inserted_at}` where the user struct has its `authenticated_at` field set from the token record
5. Return `{:ok, query}`

**Test Assertions**:

### build_email_token/2

Generates a URL-safe base64-encoded token for email delivery and returns a tuple of the encoded token string and an unsaved UserToken struct containing the SHA-256 hash. The plain token is sent to the user; only the hash is persisted.

```elixir
@spec build_email_token(User.t(), String.t()) :: {String.t(), UserToken.t()}
```

**Process**:
1. Generate 32 random bytes using `:crypto.strong_rand_bytes/1`
2. Compute the SHA-256 hash of the raw bytes using `:crypto.hash/2`
3. Encode the raw bytes as a URL-safe base64 string without padding
4. Return a two-element tuple: the encoded string and a UserToken struct with the hashed token, the given context, `sent_to` set to `user.email`, and the given user_id

**Test Assertions**:

### verify_magic_link_token_query/1

Decodes a URL-safe base64 magic-link token, hashes it, and builds an Ecto query that looks up the matching user enforcing a 15-minute expiry and an email match between the token's `sent_to` field and the current user email.

```elixir
@spec verify_magic_link_token_query(String.t()) :: {:ok, Ecto.Query.t()} | :error
```

**Process**:
1. Attempt to URL-safe base64 decode the token string without padding
2. On decode failure, return `:error` immediately
3. On success, compute the SHA-256 hash of the decoded bytes
4. Build a base query filtering UserToken by the hashed token and context "login"
5. Join the associated User record
6. Add a where clause requiring `inserted_at` to be within the last 15 minutes
7. Add a where clause requiring `token.sent_to == user.email` to guard against stale tokens after email changes
8. Select a tuple of `{user, token}`
9. Return `{:ok, query}`

**Test Assertions**:

### verify_change_email_token_query/2

Decodes a URL-safe base64 change-email token, hashes it, and builds an Ecto query that looks up the matching UserToken enforcing a 7-day expiry. The context argument must start with the prefix "change:".

```elixir
@spec verify_change_email_token_query(String.t(), String.t()) :: {:ok, Ecto.Query.t()} | :error
```

**Process**:
1. Pattern match the context argument to confirm it starts with "change:"
2. Attempt to URL-safe base64 decode the token string without padding
3. On decode failure, return `:error` immediately
4. On success, compute the SHA-256 hash of the decoded bytes
5. Build a base query filtering UserToken by the hashed token and the full context string
6. Add a where clause requiring `inserted_at` to be within the last 7 days
7. Return `{:ok, query}`

**Test Assertions**:

## Dependencies

- Ecto.Schema
- Ecto.Query
- MetricFlow.Users.User

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| token | binary | Yes | Raw or hashed authentication token | Binary; raw for session context, SHA-256 hash for email contexts |
| context | string | Yes | Token purpose identifier | "session", "login", or "change:" prefixed string |
| sent_to | string | No | Email address the token was sent to | Used for email-context tokens; nil for session tokens |
| authenticated_at | utc_datetime | No | Time of the authentication event | Set on session tokens; nil for email tokens |
| user_id | integer | Yes | Foreign key to users table | References MetricFlow.Users.User |
| inserted_at | utc_datetime | Yes (auto) | Timestamp when token was created | Auto-generated; used for expiry calculations; no updated_at |
