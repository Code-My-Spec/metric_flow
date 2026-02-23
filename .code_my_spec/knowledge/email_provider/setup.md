# Email Provider: Setup and Patterns

MetricFlow uses Swoosh (~> 1.16) for email delivery with Postmark as the production adapter.
The `Swoosh.Adapters.Postmark` adapter ships inside the `swoosh` package — no additional
Mix dependency is required.

See `docs/architecture/decisions/email_provider.md` for the full rationale behind
choosing Postmark over Resend, Mailgun, SES, and SendGrid.

---

## 1. Stack Overview

| Environment | Adapter | Purpose |
|---|---|---|
| dev | `Swoosh.Adapters.Local` | In-process mailbox, browser preview at `/dev/mailbox` |
| test | `Swoosh.Adapters.Test` | Captures emails in-memory; assert with `assert_email_sent/1` |
| prod/staging | `Swoosh.Adapters.Postmark` | Real delivery via Postmark API |

The mailer module is `MetricFlow.Infrastructure.Mailer`, defined in
`lib/metric_flow/infrastructure/mailer.ex`:

```elixir
defmodule MetricFlow.Infrastructure.Mailer do
  use Swoosh.Mailer, otp_app: :metric_flow
end
```

---

## 2. Configuration

### config/config.exs — Base (dev default)

```elixir
# Mailer — Local adapter for development
config :metric_flow, MetricFlow.Infrastructure.Mailer, adapter: Swoosh.Adapters.Local
```

The `api_client` is disabled in dev and test because it is only needed by production
HTTP-based adapters:

```elixir
# config/dev.exs
config :swoosh, :api_client, false
```

### config/test.exs — Test

```elixir
config :metric_flow, MetricFlow.Infrastructure.Mailer, adapter: Swoosh.Adapters.Test

# Disable api_client in tests — not needed for the in-memory adapter
config :swoosh, :api_client, false
```

### config/runtime.exs — Production

Add the following block inside the `if config_env() == :prod do` section:

```elixir
config :metric_flow, MetricFlow.Infrastructure.Mailer,
  adapter: Swoosh.Adapters.Postmark,
  api_key: System.fetch_env!("POSTMARK_API_KEY")
```

The Swoosh API client must be enabled for production adapters. Add this in
`config/prod.exs` (or compile-time prod config) — it must be set at compile time,
not in `runtime.exs`:

```elixir
# config/prod.exs
config :swoosh, :api_client, Swoosh.ApiClient.Req
```

MetricFlow already depends on `req ~> 0.5`, so `Swoosh.ApiClient.Req` is available
without adding a dependency.

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `POSTMARK_API_KEY` | prod, staging | Server API token from the Postmark dashboard |

Provision a separate Postmark server for staging so staging activity does not appear
in production metrics or affect production sending reputation.

---

## 3. Development Mode: Local Mailbox Viewer

In development, `Swoosh.Adapters.Local` stores sent emails in memory. The mailbox viewer
is a Plug forwarded in the router:

```elixir
# lib/metric_flow_web/router.ex
if Application.compile_env(:metric_flow, :dev_routes) do
  scope "/dev" do
    pipe_through :browser
    live_dashboard "/dashboard", metrics: MetricFlowWeb.Telemetry
    forward "/mailbox", Plug.Swoosh.MailboxPreview
  end
end
```

Visit `http://localhost:4000/dev/mailbox` after triggering an email (e.g. going through
the magic-link login flow) to inspect the rendered email text, subject, and recipient.

The `dev_routes: true` flag is set in `config/dev.exs`:

```elixir
config :metric_flow, dev_routes: true
```

This flag is checked at compile time, so the mailbox routes are not compiled into
production builds.

---

## 4. Notifier Module Patterns

Notifier modules are the application's interface for sending email. They live in their
domain context directory (not in `Infrastructure`) and call the shared
`MetricFlow.Infrastructure.Mailer` to deliver.

### Current Notifiers

| Module | Location | Emails Sent |
|---|---|---|
| `MetricFlow.Users.UserNotifier` | `lib/metric_flow/users/user_notifier.ex` | Magic link login, email-change instructions, account confirmation |
| `MetricFlow.Invitations.InvitationNotifier` | `lib/metric_flow/invitations/invitation_notifier.ex` | Invitation, reminder, cancellation, welcome |

### Standard Structure

Each notifier follows the same pattern: a private `deliver/3` function builds the
`Swoosh.Email` struct and calls `Mailer.deliver/1`. Public functions compose the
subject and body for specific email types.

```elixir
defmodule MetricFlow.Users.UserNotifier do
  import Swoosh.Email

  alias MetricFlow.Infrastructure.Mailer

  # All emails go through this single delivery function.
  # Swap the `from` address here if you need to vary it per-notifier.
  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from({"MetricFlow", "noreply@metricflow.app"})
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  @doc "Send a magic-link login email to an already-confirmed user."
  def deliver_login_instructions(user, url) do
    deliver(user.email, "Log in to MetricFlow", """
    Hi #{user.email},

    Click the link below to log in. It expires in 10 minutes.

    #{url}

    If you didn't request this, you can safely ignore it.
    """)
  end
end
```

### Return Convention

All public notifier functions return `{:ok, %Swoosh.Email{}}` on success or
`{:error, reason}` on failure. Callers in the context layer (e.g. `MetricFlow.Users`)
treat the result with a `with` clause:

```elixir
with {:ok, _email} <- UserNotifier.deliver_login_instructions(user, url) do
  {:ok, user}
end
```

### Adding a New Notifier

1. Create the module in the domain subdirectory, e.g.
   `lib/metric_flow/billing/billing_notifier.ex`.
2. `import Swoosh.Email` and `alias MetricFlow.Infrastructure.Mailer`.
3. Write a private `deliver/3` (or `deliver/4` if the from address varies).
4. Write one public function per email type.
5. Add a test file at `test/metric_flow/billing/billing_notifier_test.exs` using
   `Swoosh.Adapters.Test` assertions (see section 6 below).

---

## 5. Agency White-Label Sender Domain

MetricFlow's agency feature allows each agency to send emails from their own brand
domain (e.g. `noreply@clientagency.com`) rather than from `metricflow.app`.

### WhiteLabelConfig Schema (planned)

The `MetricFlow.Agencies.WhiteLabelConfig` schema will store per-agency sending
configuration:

```elixir
schema "agency_white_label_configs" do
  field :sender_name, :string       # e.g. "Acme Analytics"
  field :sender_domain, :string     # e.g. "acmeanalytics.com"
  field :domain_status, Ecto.Enum,
    values: [:pending, :verified, :failed],
    default: :pending

  belongs_to :agency, MetricFlow.Agencies.Agency
  timestamps()
end
```

### Dynamic From Address in Notifiers

Notifiers that send on behalf of an agency accept an optional `%WhiteLabelConfig{}`
and select the `from` address via pattern-matched private helpers:

```elixir
defmodule MetricFlow.Invitations.InvitationNotifier do
  import Swoosh.Email

  alias MetricFlow.Infrastructure.Mailer
  alias MetricFlow.Agencies.WhiteLabelConfig
  alias MetricFlow.Invitations.Invitation

  # Default MetricFlow sender — used when no white-label config exists
  defp from_address(nil), do: {"MetricFlow", "noreply@metricflow.app"}

  # Agency-branded sender — used when the agency has a verified domain
  defp from_address(%WhiteLabelConfig{sender_domain: domain, sender_name: name}),
    do: {name, "noreply@#{domain}"}

  defp deliver(recipient, subject, body, white_label \\ nil) do
    email =
      new()
      |> to(recipient)
      |> from(from_address(white_label))
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  def deliver_invitation_email(%Invitation{} = invitation, url, white_label \\ nil) do
    deliver(
      invitation.email,
      "You're invited to join #{invitation.account.name}",
      """
      Hi there,

      You've been invited to join #{invitation.account.name}.

      Click the link below to accept:
      #{url}

      This invitation expires in 7 days.
      """,
      white_label
    )
  end
end
```

### Postmark Domain Verification

Before emails can be sent from an agency domain, that domain must be verified in
Postmark. The verification flow:

1. Agency admin enters their sender domain in the white-label settings UI.
2. MetricFlow calls the Postmark Sender Signatures API to register the domain.
3. Postmark returns DKIM DNS records for the agency to add to their DNS.
4. MetricFlow polls (or receives a webhook) to check verification status.
5. `domain_status` is updated to `:verified` once DNS propagation is confirmed.
6. Only notifiers with `:verified` white-label configs should pass the struct to
   `deliver/4`; unverified domains should fall through to `from_address(nil)`.

The Postmark Sender Signatures API endpoint is:

```
POST https://api.postmarkapp.com/senders
Authorization: X-Postmark-Account-Token <account-token>

{
  "FromEmail": "noreply@clientagency.com",
  "Name": "Acme Analytics",
  "ReplyToEmail": "",
  "ReturnPathDomain": "pm-bounces.clientagency.com"
}
```

This is implementation work tracked separately — the adapter selection decision
does not depend on it being built first.

---

## 6. Test Mode

In the test environment, `Swoosh.Adapters.Test` captures all sent emails in an
ETS-backed inbox. No emails are actually delivered.

### Asserting Email Was Sent

Import `Swoosh.TestAssertions` in your test module and use `assert_email_sent/1`:

```elixir
defmodule MetricFlow.Users.UserNotifierTest do
  use MetricFlow.DataCase
  import Swoosh.TestAssertions

  alias MetricFlow.Users.UserNotifier

  test "deliver_login_instructions sends magic link email" do
    user = %{email: "test@example.com", confirmed_at: ~N[2024-01-01 00:00:00]}
    url = "https://metricflow.app/users/log-in/abc123"

    {:ok, _email} = UserNotifier.deliver_login_instructions(user, url)

    assert_email_sent(
      to: [{"", "test@example.com"}],
      subject: "Log in to MetricFlow"
    )
  end
end
```

`assert_email_sent/1` accepts a keyword list of fields to match. Unspecified fields
are not checked. All of these are valid match keys: `to`, `from`, `subject`,
`text_body`, `html_body`, `cc`, `bcc`.

### Asserting No Email Was Sent

```elixir
import Swoosh.TestAssertions

assert_no_email_sent()
```

### Resetting the Inbox Between Tests

The test inbox is automatically cleared between tests when using `DataCase` or
`ConnCase` (both call `Ecto.Adapters.SQL.Sandbox.checkout/1` which runs in a
supervised process). If for some reason you need to clear it manually:

```elixir
Swoosh.Adapters.Test.init()
```

### Swoosh API Client in Tests

`config/test.exs` disables the Swoosh API client:

```elixir
config :swoosh, :api_client, false
```

This prevents the test adapter from attempting any HTTP calls and eliminates the
`no process` warning that appears if the API client GenServer is not started.

---

## 7. Postmark-Specific Features (Provider Options)

The Swoosh Postmark adapter supports extra options passed via `put_provider_option/3`.
These are available when needed but are not required for basic delivery.

### Message Streams

Postmark separates sending infrastructure by stream. The default stream for
transactional email is `"outbound"`. Use a separate stream for any notification-style
bulk sends to protect transactional reputation:

```elixir
email
|> put_provider_option(:message_stream, "outbound")  # default for transactional
```

### Tagging for Analytics

Tag emails in the Postmark dashboard for per-type open and click reporting:

```elixir
email
|> put_provider_option(:tag, "magic-link")
```

Recommended tags for MetricFlow:
- `"magic-link"` — login and confirmation emails
- `"invitation"` — invitation and welcome emails
- `"email-change"` — email update instructions

### Open and Click Tracking

Opt in per-email:

```elixir
email
|> put_provider_option(:track_opens, true)
|> put_provider_option(:track_links, "None")  # "None" | "HtmlAndText" | "HtmlOnly" | "TextOnly"
```

For transactional emails (magic links, confirmations), it is reasonable to track
opens but not links. For invitation emails, tracking both is useful for engagement
visibility.

### Template Support (future)

If Postmark-hosted templates are ever used, they are invoked with:

```elixir
email
|> put_provider_option(:template_alias, "magic-link")
|> put_provider_option(:template_model, %{url: url, email: user.email})
```

Currently all templates are rendered server-side by Phoenix/EEx inside the notifier
modules, which keeps template logic inside the application and version-controlled.

---

## 8. Upgrading Swoosh

The current constraint is `~> 1.16`. The Postmark adapter has been stable across all
Swoosh 1.x releases. `Swoosh.Adapters.Resend` was added in 1.20.0 — that is the only
notable addition relevant to MetricFlow in recent releases. To upgrade:

```bash
mix deps.update swoosh
```

No configuration changes are expected for a minor version bump within the `~> 1.16`
constraint.
