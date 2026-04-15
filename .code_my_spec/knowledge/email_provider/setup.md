# Email Provider: Setup and Patterns

MetricFlow uses Swoosh (~> 1.16) for email delivery with Mailgun as the production adapter.
The `Swoosh.Adapters.Mailgun` adapter ships inside the `swoosh` package — no additional
Mix dependency is required.

See `.code_my_spec/architecture/decisions/email_provider.md` for the full rationale behind
choosing Mailgun over Postmark, Resend, SES, and SendGrid.

---

## 1. Stack Overview

| Environment | Adapter | Purpose |
|---|---|---|
| dev | `Swoosh.Adapters.Local` | In-process mailbox, browser preview at `/dev/mailbox` |
| test | `Swoosh.Adapters.Test` | Captures emails in-memory; assert with `assert_email_sent/1` |
| prod/staging | `Swoosh.Adapters.Mailgun` | Real delivery via Mailgun API |

The mailer module is `MetricFlow.Mailer`, defined in
`lib/metric_flow/mailer.ex`:

```elixir
defmodule MetricFlow.Mailer do
  use Swoosh.Mailer, otp_app: :metric_flow
end
```

---

## 2. Configuration

### config/config.exs — Base (dev default)

```elixir
# Mailer — Local adapter for development
config :metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Local
```

The `api_client` is disabled in dev and test because it is only needed by production
HTTP-based adapters:

```elixir
# config/dev.exs
config :swoosh, :api_client, false
```

### config/test.exs — Test

```elixir
config :metric_flow, MetricFlow.Mailer, adapter: Swoosh.Adapters.Test

# Disable api_client in tests — not needed for the in-memory adapter
config :swoosh, :api_client, false
```

### config/runtime.exs — Production

Add the following block inside the `if config_env() == :prod do` section:

```elixir
config :metric_flow, MetricFlow.Mailer,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: System.fetch_env!("MAILGUN_API_KEY"),
  domain: System.fetch_env!("MAILGUN_DOMAIN")
```

The Swoosh API client must be enabled for production adapters. This is set in
`config/prod.exs` (compile-time prod config):

```elixir
# config/prod.exs
config :swoosh, :api_client, Swoosh.ApiClient.Req
```

MetricFlow already depends on `req ~> 0.5`, so `Swoosh.ApiClient.Req` is available
without adding a dependency.

### Environment Variables

| Variable | Required | Description |
|---|---|---|
| `MAILGUN_API_KEY` | prod, staging | API key from the Mailgun dashboard (starts with `key-`) |
| `MAILGUN_DOMAIN` | prod, staging | Sending domain configured in Mailgun (e.g. `mg.metricflow.app`) |

Use a separate Mailgun domain for staging so staging activity does not affect
production sending reputation.

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

---

## 4. Notifier Module Patterns

Notifier modules are the application's interface for sending email. They live in their
domain context directory and call the shared `MetricFlow.Mailer` to deliver.

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

  alias MetricFlow.Mailer

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

---

## 5. Agency White-Label Sender Domain

MetricFlow's agency feature allows each agency to send emails from their own brand
domain (e.g. `noreply@clientagency.com`) rather than from `metricflow.app`.

### Dynamic From Address in Notifiers

Notifiers that send on behalf of an agency accept an optional `%WhiteLabelConfig{}`
and select the `from` address via pattern-matched private helpers:

```elixir
defp from_address(nil), do: {"MetricFlow", "noreply@metricflow.app"}
defp from_address(%WhiteLabelConfig{sender_domain: domain, sender_name: name}),
  do: {name, "noreply@#{domain}"}
```

### Mailgun Domain Verification

Each agency sender domain must be verified in Mailgun before emails can be sent from it.
Mailgun provides a Domain Verification API:

```
POST https://api.mailgun.net/v3/domains
Authorization: Basic api:<api-key>

{
  "name": "clientagency.com"
}
```

The response includes DNS records (SPF, DKIM, MX) that the agency must add. Verification
status can be checked via:

```
GET https://api.mailgun.net/v3/domains/clientagency.com
```

---

## 6. Test Mode

In the test environment, `Swoosh.Adapters.Test` captures all sent emails in an
ETS-backed inbox. No emails are actually delivered.

### Asserting Email Was Sent

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

### Asserting No Email Was Sent

```elixir
import Swoosh.TestAssertions

assert_no_email_sent()
```
