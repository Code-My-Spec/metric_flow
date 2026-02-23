# Email Delivery Provider

## Status
Proposed

## Context

MetricFlow is a Phoenix SaaS application using Swoosh (~> 1.16) for email delivery. Two notifier modules are already in place:

- `MetricFlow.Users.UserNotifier` — login magic links, email confirmation, email-change instructions
- `MetricFlow.Invitations.InvitationNotifier` — invitation send, reminder, cancellation, and welcome emails

Both modules currently use a plain text body and a hardcoded `from` address (`contact@example.com` / `contact@MetricFlow.com`). The `Local` adapter is configured for development, with production adapter selection deferred to `config/runtime.exs`.

The application includes an agency white-label feature (`MetricFlow.Agencies.WhiteLabelConfig`) that requires agencies to send transactional emails under their own brand — meaning the `from` domain must be configurable per account, not fixed to a single MetricFlow domain.

### Requirements

- Transactional email only (magic links, confirmations, invitations, notifications)
- Reliable delivery with bounce and open tracking
- Custom sender domain support for agency white-labeling (multiple `from` domains, not just one)
- Swoosh adapter that is well-maintained and ships as part of Swoosh core
- Reasonable free tier for development and early production
- Low operational overhead — no infrastructure to manage

### Volume Expectations

Early stage: hundreds of emails per month. At steady state with agencies onboarded: tens of thousands per month across many sender domains.

---

## Options Considered

### Option A: Postmark (`Swoosh.Adapters.Postmark`)

Postmark is a transactional-email-only provider founded in 2010. Its adapter ships as a first-party adapter in Swoosh core and has been stable across Swoosh 1.x.

**Deliverability:** Industry-leading. Independent studies (Mailtrap, March 2025) put Postmark inbox placement at 83.3% — highest among tested providers. Postmark separates transactional and broadcast infrastructure, protecting critical emails from any reputation spillover.

**Custom sender domains:** Fully supported. Postmark supports both domain-level verification (send from any address on a verified domain) and individual sender signatures. There is no cap on the number of verified sender domains on any paid plan; the free tier allows up to 5 domains. Agencies can be onboarded programmatically via the Sender Signatures API, which means MetricFlow can register and verify a client's domain on their behalf.

**Swoosh adapter:** `Swoosh.Adapters.Postmark` ships in Swoosh core. Supports `message_stream`, `tag`, `template_id`, `template_alias`, `template_model`, `track_opens`, and `track_links` provider options. The adapter is tested in the Swoosh CI suite.

**Pricing:**
- Free: 100 emails/month, no expiry, no credit card — adequate for development
- Basic: $15/month for 10,000 emails ($1.80/1,000 overage)
- Pro: $16.50/month for 10,000 emails ($1.30/1,000 overage); up to 10 sender domains
- Platform: $18/month; unlimited sender domains — best fit for multi-agency use

**Pros:**
- Best deliverability reputation in the transactional email market
- Unlimited sender domains available on Platform plan; 5 on free tier, 10 on Pro
- Sender Signatures API supports programmatic domain registration for white-labeling
- Adapter ships in Swoosh core; no additional dependency required
- Generous developer free tier (no expiry, no credit card)
- Clean support for message streams to separate transactional from any future notifications
- Inbound email parsing available if needed later

**Cons:**
- More expensive per email than AWS SES or Resend at scale
- No built-in HTML template engine; templates are rendered by Phoenix/HEEx (not a blocker — current notifiers already do this)

---

### Option B: Resend (`Swoosh.Adapters.Resend`)

Resend is a newer (2023) developer-focused provider that has grown rapidly in the Elixir/Phoenix community.

**Deliverability:** Good, with dynamically scaled IPs to handle variable traffic. No long track record comparable to Postmark. No independently published inbox placement numbers.

**Custom sender domains:** Free plan supports only 1 custom domain. Pro ($20/month) expands to 10 domains. Scale ($90/month) supports 10 domains. For an agency product managing dozens or hundreds of client sender domains, Resend's tiering is a poor fit — multiple client domains would require the Scale or Enterprise tier from launch.

**Swoosh adapter:** `Swoosh.Adapters.Resend` was added to Swoosh core in v1.20.0. MetricFlow uses `~> 1.16`, so `1.20.0` is within the constraint but the adapter was not available at the time the constraint was written. The community package `resend` (Hex.pm) also provides `Resend.Swoosh.Adapter` but adds an extra dependency.

**Pricing:**
- Free: 3,000 emails/month, 100/day max, 1 domain
- Pro: $20/month for 50,000 emails, 10 domains
- Scale: $90/month for 100,000 emails, 10 domains
- Dedicated IPs: $30/month add-on (Scale and above)

**Pros:**
- Modern API with good developer experience
- Generous free tier volume (3,000/month vs Postmark's 100/month)
- Competitive per-email pricing at scale
- Managed dedicated IP warmup

**Cons:**
- Domain limit is a hard blocker for the agency white-label requirement: 1 domain on free, 10 on Pro, 10 on Scale — insufficient for multi-client agency use without Enterprise pricing
- Shorter track record than Postmark for deliverability
- `Swoosh.Adapters.Resend` added in 1.20.0 — relatively new in the Swoosh core release stream
- No inbound email support

---

### Option C: Mailgun (`Swoosh.Adapters.Mailgun`)

Mailgun is a developer-oriented API provider with a long history and solid documentation.

**Deliverability:** Mailtrap study places Mailgun at 71.4% inbox placement — below Postmark. Customer reviews note inconsistent deliverability and sending speed.

**Custom sender domains:** Foundation plan ($35/month, 50,000 emails) supports 1,000 custom sending domains — the most permissive tier for multi-domain use. Basic plan ($15/month) supports only 1 domain, which rules it out for early-stage white-label use.

**Swoosh adapter:** `Swoosh.Adapters.Mailgun` ships in Swoosh core. Stable and well-tested.

**Pricing:**
- Free: 100 emails/day, 1 domain
- Basic: $15/month for 10,000 emails, 1 domain
- Foundation: $35/month for 50,000 emails, 1,000 domains
- Scale: $90/month for 100,000 emails, dedicated IP included

**Pros:**
- 1,000 domains on Foundation plan is excellent for agency white-labeling
- Adapter ships in Swoosh core
- Advanced analytics and inbound routing

**Cons:**
- Worse deliverability than Postmark (71.4% vs 83.3% inbox placement)
- Custom domain support only becomes viable at the $35/month Foundation tier
- Mixed customer support reviews
- Sinch/Mailgun acquisition history has introduced pricing and support instability

---

### Option D: AWS SES (`Swoosh.Adapters.AmazonSES`)

AWS SES is the lowest-cost option at scale, priced at $0.10 per 1,000 emails.

**Deliverability:** Opaque — AWS does not publish deliverability metrics. Requires significant self-management of sending reputation, bounce handling, and complaint feedback loops.

**Custom sender domains:** Fully supported — any number of verified domains. However, each domain requires IAM policy configuration and DNS verification through the AWS console or API.

**Swoosh adapter:** `Swoosh.Adapters.AmazonSES` ships in Swoosh core. Requires `:gen_smtp` as an additional dependency. An alternative `Swoosh.Adapters.ExAwsAmazonSES` requires `:ex_aws`.

**Pricing:**
- Free tier: 3,000 emails/month for the first 12 months, then standard rate
- Standard: $0.10/1,000 emails (cheapest at high volume)

**Pros:**
- Cheapest option at high volume
- No domain limits
- Already within the AWS ecosystem if other AWS services are used

**Cons:**
- Production access requires manually leaving SES sandbox via an AWS Support ticket, with a 24-hour review — a meaningful operational hurdle
- Sandbox limits deliverable addresses to verified recipients only — cannot send to real users until approved
- DNS, DKIM, SPF, and DMARC setup is manual and non-trivial
- No transparent deliverability metrics
- Additional dependency required (`:gen_smtp` or `:ex_aws`)
- High operational burden for a team at early stage

---

### Option E: SendGrid (`Swoosh.Adapters.Sendgrid`)

SendGrid is the most widely recognized email provider, offering both transactional and marketing email.

**Deliverability:** Mixed. Independent reviewers note IP reputation issues on shared pools; customers are routinely advised to upgrade to dedicated IP plans to resolve deliverability problems.

**Custom sender domains:** Supported, but dedicated IP plans (required for reliable deliverability) start at $89.95/month.

**Pros:**
- Widely used, large ecosystem
- Adapter ships in Swoosh core

**Cons:**
- Lowest deliverability in independent tests among the options considered
- Complex pricing — dedicated IPs necessary for acceptable deliverability add substantial cost
- Perceived quality declined following Twilio acquisition
- Not a good fit for transactional-only workloads

---

## Decision

**Postmark is recommended**, with the Platform plan targeted for production once agency white-labeling is active.

The agency white-label requirement is the decisive constraint. MetricFlow must support multiple client-owned sender domains from which transactional emails are dispatched. Among providers with a well-maintained Swoosh adapter, Postmark is the only one that:

1. Provides unlimited sender domains on a plan that remains cost-reasonable for an early-stage SaaS ($18/month Platform)
2. Delivers the best independently verified inbox placement rate (83.3%)
3. Offers a programmatic Sender Signatures API that allows MetricFlow to register and verify client domains without manual intervention per client
4. Ships a stable, first-party Swoosh adapter requiring no additional dependencies

Resend's domain limits (1 on free, 10 on Pro and Scale) are a structural mismatch for an agency product. Mailgun reaches parity on domain count only at the $35/month Foundation tier and has materially worse deliverability. AWS SES is operationally expensive to operate correctly and requires manual sandbox exit before any real users can receive email.

For development, the existing `Swoosh.Adapters.Local` configuration is retained — no changes needed to `config/config.exs`.

### Configuration

The adapter is set in `config/runtime.exs` for production:

```elixir
config :metric_flow, MetricFlow.Infrastructure.Mailer,
  adapter: Swoosh.Adapters.Postmark,
  api_key: System.fetch_env!("POSTMARK_API_KEY")
```

No new Mix dependencies are required. `Swoosh.Adapters.Postmark` ships with the `swoosh` package already in `mix.exs`.

### White-Label Integration Design

The `MetricFlow.Agencies.WhiteLabelConfig` schema should store a `sender_domain` and `sender_name` field. Notifier modules should accept a `%WhiteLabelConfig{}` (or nil) to select the `from` address dynamically:

```elixir
# In InvitationNotifier — example of dynamic from address
defp from_address(nil), do: {"MetricFlow", "noreply@metricflow.app"}
defp from_address(%WhiteLabelConfig{sender_domain: domain, sender_name: name}),
  do: {name, "noreply@#{domain}"}
```

Each agency sender domain must be verified in Postmark before emails can be sent from it. Verification should be triggered during the agency white-label configuration flow and tracked with a status field (`:pending`, `:verified`, `:failed`).

---

## Consequences

- **No dependency change** — `swoosh` is already in `mix.exs`; `Swoosh.Adapters.Postmark` is included
- **Environment variable required** — `POSTMARK_API_KEY` must be provisioned in production and staging environments
- **Staging isolation** — a separate Postmark server (or message stream) should be used for staging to avoid polluting production metrics
- **Agency onboarding complexity** — adding white-label email sending requires building a domain verification flow backed by the Postmark Sender Signatures API; this is follow-up implementation work, not part of the adapter selection
- **Cost at scale** — Postmark is not the cheapest option at high volume; if sending volume grows to millions of emails per month, a re-evaluation against AWS SES should be performed
- **Deliverability monitoring** — Postmark's dashboard provides bounce and open tracking out of the box; webhooks can feed this data back into MetricFlow for per-account health monitoring
- **Test suite** — `Swoosh.Adapters.Test` (already the default for `Mix.env() == :test`) continues to be used in tests; no change to test configuration required
