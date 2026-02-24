# MetricFlow.Users.User

Ecto schema representing a registered user in the MetricFlow system. Stores email, bcrypt-hashed password, and account confirmation timestamp. The password field is virtual and redacted; hashed_password is redacted to prevent accidental log exposure. Provides changesets for email registration and updates, password changes (with optional hashing for LiveView validations), and account confirmation. Exposes valid_password?/2 for timing-safe password verification that prevents user enumeration attacks by calling Bcrypt.no_user_verify/0 when no valid user is present.

## Delegates

None.

## Functions

### email_changeset/3

Builds a changeset for registering or changing a user's email address. Validates format, length, and uniqueness by default. Accepts opts to skip uniqueness validation for live form feedback.

```elixir
@spec email_changeset(User.t(), map(), keyword()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast the :email field from attrs
2. Validate :email is required
3. Validate :email matches format ~r/^[^@,;\s]+@[^@,;\s]+$/ with message "must have the @ sign and no spaces"
4. Validate :email length does not exceed 160 characters
5. If opts[:validate_unique] is not false, run unsafe_validate_unique/3 against MetricFlow.Repo
6. If opts[:validate_unique] is not false, add unique_constraint on :email
7. If opts[:validate_unique] is not false, validate the email value has actually changed (add error "did not change" if unchanged)
8. Return the resulting changeset

**Test Assertions**:

### password_changeset/3

Builds a changeset for setting or changing a user's password. Validates length and confirmation match. Hashes the password and clears the virtual field before persisting by default; hashing can be disabled for LiveView validations.

```elixir
@spec password_changeset(User.t(), map(), keyword()) :: Ecto.Changeset.t()
```

**Process**:
1. Cast the :password field from attrs
2. Validate :password_confirmation matches :password with message "does not match password"
3. Validate :password is required
4. Validate :password length is between 12 and 72 characters (inclusive)
5. If opts[:hash_password] is not false and changeset is valid, validate :password byte length does not exceed 72 bytes
6. If opts[:hash_password] is not false and changeset is valid, put_change :hashed_password to Bcrypt.hash_pwd_salt(password)
7. If opts[:hash_password] is not false and changeset is valid, delete_change :password to clear the virtual field
8. Return the resulting changeset

**Test Assertions**:

### confirm_changeset/1

Builds a changeset that marks the user account as confirmed by setting confirmed_at to the current UTC time (second precision).

```elixir
@spec confirm_changeset(User.t()) :: Ecto.Changeset.t()
```

**Process**:
1. Get current UTC datetime with second precision via DateTime.utc_now(:second)
2. Return a changeset with confirmed_at set to that datetime

**Test Assertions**:

### valid_password?/2

Performs a timing-safe check to verify that a plaintext password matches the user's stored bcrypt hash. Calls Bcrypt.no_user_verify/0 when no hashed_password is present to prevent timing-based user enumeration.

```elixir
@spec valid_password?(User.t() | any(), String.t() | any()) :: boolean()
```

**Process**:
1. Pattern match: if first argument is a User struct with a binary hashed_password and second argument is a non-empty binary password, call Bcrypt.verify_pass(password, hashed_password) and return its result
2. Otherwise, call Bcrypt.no_user_verify() to consume equivalent time, then return false

**Test Assertions**:

## Dependencies

- Ecto.Schema
- Ecto.Changeset
- MetricFlow.Repo
- Bcrypt

## Fields

| Field | Type | Required | Description | Constraints |
|-------|------|----------|-------------|-------------|
| id | integer | Yes (auto) | Primary key | Auto-generated |
| email | string | Yes | User's email address | Max: 160, must match ~r/^[^@,;\s]+@[^@,;\s]+$/, unique |
| password | string | No | Virtual plaintext password (never persisted) | Virtual, redacted, min: 12, max: 72 characters |
| hashed_password | string | No | Bcrypt hash of the user's password | Redacted, populated by password_changeset/3 |
| confirmed_at | utc_datetime | No | Timestamp when the user confirmed their email | Nil until confirm_changeset/1 is applied |
| authenticated_at | utc_datetime | No | Virtual field set by the session system at login | Virtual, never persisted |
| inserted_at | utc_datetime | Yes (auto) | Timestamp when the record was created | Auto-generated |
| updated_at | utc_datetime | Yes (auto) | Timestamp when the record was last updated | Auto-generated |
