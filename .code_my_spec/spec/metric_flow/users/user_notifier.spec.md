# MetricFlow.Users.UserNotifier

Email delivery module using Swoosh. Sends transactional authentication emails via MetricFlow.Mailer. Delivers update-email confirmation instructions and magic link login instructions. Dispatches confirmation instructions (subject: "Confirmation instructions") for unconfirmed users and login instructions (subject: "Log in instructions") for confirmed users, branching on the user's confirmed_at field.

## Delegates

None

## Functions

### deliver_update_email_instructions/2

Sends an email to the user with a URL to confirm their requested email address change.

```elixir
@spec deliver_update_email_instructions(User.t(), String.t()) :: {:ok, Swoosh.Email.t()} | {:error, term()}
```

**Process**:
1. Compose a plain-text email body containing the update URL and the user's email address
2. Call the private deliver/3 helper with the user's email address, the subject "Update email instructions", and the composed body
3. Build a Swoosh.Email struct with to, from ("MetricFlow" / contact@example.com), subject, and text body
4. Deliver via MetricFlow.Mailer.deliver/1
5. Return {:ok, email} on success or propagate {:error, reason} from the mailer

**Test Assertions**:

### deliver_login_instructions/2

Dispatches the appropriate login email based on the user's confirmation status. Unconfirmed users (confirmed_at is nil) receive account confirmation instructions; confirmed users receive magic link login instructions.

```elixir
@spec deliver_login_instructions(User.t(), String.t()) :: {:ok, Swoosh.Email.t()} | {:error, term()}
```

**Process**:
1. Pattern-match on the user struct to inspect the confirmed_at field
2. If confirmed_at is nil, delegate to the private deliver_confirmation_instructions/2
3. If confirmed_at is set, delegate to the private deliver_magic_link_instructions/2
4. Each private function composes a plain-text body containing the URL and calls deliver/3
5. Return {:ok, email} on success or propagate {:error, reason} from the mailer

**Test Assertions**:

## Dependencies

- Swoosh.Email
- MetricFlow.Mailer
- MetricFlow.Users.User
