# MetricFlow.Users

User authentication, registration, and session management.

## Type

context

## Delegates

None. All functions are implemented directly in the context module.

## Functions

### get_user_by_email/1

Fetches a user record by email address. Returns nil if no user with that email exists. Used during login and registration flows before a scope is available.

```elixir
@spec get_user_by_email(String.t()) :: User.t() | nil
```

**Process**:
1. Query the users table for a record with a matching email field
2. Return the User struct if found, otherwise return nil

**Test Assertions**:
- returns the user if the email exists
- does not return the user if the email does not exist

### get_user_by_email_and_password/2

Fetches a user by email and verifies the plaintext password against the stored Bcrypt hash. Uses a timing-safe no-op when no user is found to prevent timing attacks.

```elixir
@spec get_user_by_email_and_password(String.t(), String.t()) :: User.t() | nil
```

**Process**:
1. Fetch user by email from the database
2. Call User.valid_password?/2 to verify the password against the stored hash
3. Return the User struct if the password is valid, otherwise return nil
4. When no user is found, call Bcrypt.no_user_verify/0 to prevent timing attacks and return nil

**Test Assertions**:
- returns the user if the email and password are valid
- does not return the user if the password is not valid
- does not return the user if the email does not exist

### get_user!/1

Fetches a single user by integer ID. Raises Ecto.NoResultsError when the user does not exist.

```elixir
@spec get_user!(integer()) :: User.t()
```

**Process**:
1. Query the users table for the record with the given primary key
2. Return the User struct if found
3. Raise Ecto.NoResultsError if no record exists

**Test Assertions**:
- returns the user with the given id
- raises if id is invalid

### register_user/1

Creates a new user with an email address. Validates email format, uniqueness, and length constraints. Currently registers users without a password (magic link flow).

```elixir
@spec register_user(map()) :: {:ok, User.t()} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Build a new User struct
2. Apply User.email_changeset/3 with the provided attrs to validate the email
3. Insert the record into the database
4. Return ok tuple with the persisted User, or error tuple with the changeset

**Test Assertions**:
- registers users with password
- requires email to be set
- validates email when given
- validates maximum values for email for security
- validates email uniqueness

### sudo_mode?/2

Checks whether the user is in sudo mode — meaning they authenticated within the last N minutes. The minutes argument is a negative integer offset applied to DateTime.utc_now/0; defaults to -20 (twenty minutes ago). Used to gate sensitive settings changes.

```elixir
@spec sudo_mode?(User.t(), integer()) :: boolean()
```

**Process**:
1. Extract the authenticated_at DateTime from the User struct
2. If authenticated_at is a DateTime struct, compare it against DateTime.utc_now() shifted by the given minutes offset (a negative value moves the threshold into the past)
3. Return true if authenticated_at is after that threshold, false otherwise
4. Return false when authenticated_at is nil or not a DateTime

**Test Assertions**:
- validates the authenticated_at time

### change_user_email/3

Returns an Ecto.Changeset for the user's email field, suitable for driving a live-validation form. Does not persist any changes.

```elixir
@spec change_user_email(User.t(), map(), keyword()) :: Ecto.Changeset.t()
```

**Process**:
1. Delegate to User.email_changeset/3 with the given user, attrs, and opts
2. Return the resulting changeset without inserting or updating

**Test Assertions**:
- returns a user changeset

### update_user_email/2

Verifies an email-change token and, if valid, atomically updates the user's email and deletes the consumed change token.

```elixir
@spec update_user_email(User.t(), String.t()) :: {:ok, User.t()} | {:error, :transaction_aborted}
```

**Process**:
1. Build the expected token context string as "change:" followed by the user's current email
2. Begin a database transaction
3. Verify the token against the change email token query for that context
4. Fetch the matching UserToken to retrieve the new email address stored in sent_to
5. Apply User.email_changeset/2 with the new email and update the user record
6. Delete all UserToken records for the user with the change context
7. Return ok tuple with updated User on success, or error tuple on any failure

**Test Assertions**:
- updates the email with a valid token
- does not update email with invalid token
- does not update email if user email changed
- does not update email if token expired

### change_user_password/3

Returns an Ecto.Changeset for the user's password field, suitable for driving a live-validation form. Does not persist any changes.

```elixir
@spec change_user_password(User.t(), map(), keyword()) :: Ecto.Changeset.t()
```

**Process**:
1. Delegate to User.password_changeset/3 with the given user, attrs, and opts
2. Return the resulting changeset without inserting or updating

**Test Assertions**:
- returns a user changeset
- allows fields to be set

### update_user_password/2

Updates the user's password and atomically expires all existing tokens for that user, invalidating all active sessions.

```elixir
@spec update_user_password(User.t(), map()) :: {:ok, {User.t(), list(UserToken.t())}} | {:error, Ecto.Changeset.t()}
```

**Process**:
1. Apply User.password_changeset/2 to the user with the given attrs
2. Within a database transaction, update the user record
3. Fetch all UserToken records for the user
4. Delete all fetched tokens
5. Return ok tuple with the updated user and the list of expired tokens, or error changeset on validation failure

**Test Assertions**:
- validates password
- validates maximum values for password for security
- updates the password
- deletes all tokens for the given user

### generate_user_session_token/1

Creates a new session token for the user, stores it in the database, and returns the raw binary token for placement in the session cookie.

```elixir
@spec generate_user_session_token(User.t()) :: binary()
```

**Process**:
1. Call UserToken.build_session_token/1 to generate a random token and a UserToken struct
2. Insert the UserToken record into the database
3. Return the raw binary token

**Test Assertions**:
- generates a token
- duplicates the authenticated_at of given user in new token

### get_user_by_session_token/1

Validates a session token and returns the associated user with authenticated_at populated, or nil if the token is invalid or expired (older than 14 days).

```elixir
@spec get_user_by_session_token(binary()) :: {User.t(), DateTime.t()} | nil
```

**Process**:
1. Call UserToken.verify_session_token_query/1 to build the lookup query
2. Execute the query via Repo.one
3. Return the tuple of user (with authenticated_at set from token) and token inserted_at, or nil if not found

**Test Assertions**:
- returns user by token
- does not return user for invalid token
- does not return user for expired token

### get_user_by_magic_link_token/1

Validates a magic link token and returns the associated user, or nil if the token is invalid or expired (older than 15 minutes). Does not consume the token.

```elixir
@spec get_user_by_magic_link_token(String.t()) :: User.t() | nil
```

**Process**:
1. Call UserToken.verify_magic_link_token_query/1 to build the lookup query
2. Execute the query via Repo.one
3. Extract and return the user from the result tuple, or nil if not found or token invalid

**Test Assertions**:
- returns user by token
- does not return user for invalid token
- does not return user for expired token

### login_user_by_magic_link/1

Authenticates a user via a magic link token, handling confirmed and unconfirmed user states. Consumes the token on success. Assumes the token is a valid URL-safe base64 string; callers should validate the token with get_user_by_magic_link_token/1 before calling this function.

```elixir
@spec login_user_by_magic_link(String.t()) :: {:ok, {User.t(), list(UserToken.t())}} | {:error, :not_found}
```

**Process**:
1. Call UserToken.verify_magic_link_token_query/1 to build the lookup query (pattern-matched directly — raises MatchError if token is not valid base64)
2. Execute the query via Repo.one to retrieve the user and token
3. If no result: return error tuple with :not_found
4. If user has no confirmed_at but has a hashed_password: raise an error (security violation — mixed auth modes)
5. If user is unconfirmed and has no password: apply User.confirm_changeset/1 and call update_user_and_delete_all_tokens/1, confirming the user and expiring all tokens
6. If user is already confirmed: delete the magic link token and return ok tuple with empty expired tokens list

**Test Assertions**:
- confirms user and expires tokens
- returns user and (deleted) token for confirmed user
- confirms unconfirmed user with password set

### deliver_user_update_email_instructions/3

Generates an email-change token and sends instructions to the user's current email address with a link to confirm the address change.

```elixir
@spec deliver_user_update_email_instructions(User.t(), String.t(), (String.t() -> String.t())) :: {:ok, Swoosh.Email.t()} | {:error, term()}
```

**Process**:
1. Call UserToken.build_email_token/2 with context "change:" followed by current_email
2. Insert the UserToken record into the database
3. Build the confirmation URL by applying update_email_url_fun to the encoded token
4. Call UserNotifier.deliver_update_email_instructions/2 with the user and URL
5. Return the result from the mailer

**Test Assertions**:
- sends token through notification

### deliver_login_instructions/2

Generates a magic link token and sends login or confirmation instructions to the user. Sends a confirmation email for unconfirmed users and a login email for confirmed users.

```elixir
@spec deliver_login_instructions(User.t(), (String.t() -> String.t())) :: {:ok, Swoosh.Email.t()} | {:error, term()}
```

**Process**:
1. Call UserToken.build_email_token/2 with context "login"
2. Insert the UserToken record into the database
3. Build the magic link URL by applying magic_link_url_fun to the encoded token
4. Call UserNotifier.deliver_login_instructions/2 with the user and URL
5. Return the result from the mailer

**Test Assertions**:
- sends token through notification

### delete_user_session_token/1

Deletes the session token from the database, effectively logging the user out of that session.

```elixir
@spec delete_user_session_token(binary()) :: :ok
```

**Process**:
1. Delete all UserToken records matching the given token binary and context "session"
2. Return :ok regardless of whether a record was found

**Test Assertions**:
- deletes the token

## Dependencies

## Components

### MetricFlow.Users.User

Ecto schema representing a registered user. Stores email, bcrypt-hashed password, and account confirmation timestamp. Provides changesets for email and password changes with validation rules (email format, uniqueness, length; password length 12-72 characters). Exposes valid_password?/2 for timing-safe password verification and confirm_changeset/1 for setting confirmed_at. The password field is virtual and redacted; hashed_password is redacted.

### MetricFlow.Users.UserToken

Ecto schema and query module for user authentication tokens. Supports three token contexts: "session" (raw binary, stored directly, valid 14 days), "login" (URL-safe base64-encoded hash, valid 15 minutes, for magic link auth and email confirmation), and "change:" prefixed tokens (URL-safe base64-encoded hash, valid 7 days, for email address changes). Provides build_session_token/1, build_email_token/2, and corresponding verify query functions for each context.

### MetricFlow.Users.UserNotifier

Email delivery module using Swoosh. Sends transactional authentication emails via MetricFlow.Mailer. Delivers update-email confirmation instructions and magic link login instructions. Dispatches confirmation instructions (subject: "Confirmation instructions") for unconfirmed users and login instructions (subject: "Log in instructions") for confirmed users, branching on the user's confirmed_at field.

### MetricFlow.Users.Scope

Caller scope struct exported by the Users boundary for use across the application. Holds the current User struct in the user field (nil for unauthenticated callers). Provides for_user/1 constructor that returns a populated Scope for a given User or nil when passed nil. Consumed as the first parameter of public context functions in all other bounded contexts.

## Fields

### MetricFlow.Users.User

| Field            | Type         | Required   | Description                                      | Constraints                         |
| ---------------- | ------------ | ---------- | ------------------------------------------------ | ----------------------------------- |
| id               | integer      | Yes (auto) | Primary key                                      | Auto-generated                      |
| email            | string       | Yes        | User's email address                             | Max 160 chars, unique, format check |
| password         | string       | No         | Virtual field for plaintext password input       | Virtual, redacted, min 12 max 72    |
| hashed_password  | string       | No         | Bcrypt hash of the user's password               | Redacted                            |
| confirmed_at     | utc_datetime | No         | Timestamp when the user confirmed their email    | Nil until confirmed                 |
| authenticated_at | utc_datetime | No         | Virtual field populated from session token       | Virtual, set at auth time           |
| inserted_at      | utc_datetime | Yes (auto) | Record creation timestamp                        | Auto-generated                      |
| updated_at       | utc_datetime | Yes (auto) | Record last-update timestamp                     | Auto-generated                      |
