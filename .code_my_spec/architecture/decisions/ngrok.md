# ngrok for Local OAuth Development

## Status

Proposed

## Context

MetricFlow's OAuth integration flows (Google, Facebook, QuickBooks) require callback URLs
that external OAuth providers can reach. During local development, `localhost` is not
accessible from the internet, making it impossible to complete OAuth callback flows
without a tunneling solution.

OAuth providers require:
- A publicly accessible callback URL registered in their developer console
- HTTPS for callback URLs (required by Google, Facebook)
- Consistent callback URL across development sessions

## Options Considered

### ngrok

Industry-standard tunneling tool that exposes local ports to the internet.

- Free tier with random subdomains
- Paid tier ($8/month) for stable custom subdomains
- HTTPS by default
- Web inspector for debugging HTTP traffic
- CLI: `ngrok http 4000`

### Cloudflare Tunnel

Free tunneling via Cloudflare's network.

- Requires a Cloudflare account and domain
- More setup than ngrok (install cloudflared, configure tunnel)
- Stable subdomains on free tier
- Better for production-like tunneling

### localhost.run

SSH-based tunneling with no installation.

- `ssh -R 80:localhost:4000 localhost.run`
- Random subdomain on free tier
- Less reliable than ngrok

### Skip Tunneling (Mock OAuth in Dev)

Use Assent's test/bypass mode to simulate OAuth without real callbacks.

- No external dependency
- Cannot test the full OAuth flow with real providers
- Useful for automated tests but not manual development

## Decision

**ngrok for local OAuth development tunneling.**

ngrok provides the simplest setup for exposing the local Phoenix server to OAuth providers
during development. The free tier is sufficient for development; a paid plan with a stable
subdomain reduces the need to update OAuth callback URLs in provider consoles.

Usage:
```bash
ngrok http 4000
```

Configure OAuth providers with the ngrok URL as the callback:
```
https://<subdomain>.ngrok-free.app/auth/:provider/callback
```

## Consequences

- Developers install ngrok locally (`brew install ngrok` or download from ngrok.com)
- OAuth provider developer consoles need the ngrok callback URL registered
- With free tier, the subdomain changes each session — callback URLs must be updated
- A shared paid ngrok account with a stable subdomain eliminates this friction
- Not required for automated tests — BDD specs use HTTP recording (see `e2e_testing.md`)
- ngrok is development-only — production OAuth callbacks use the Fly.io deployment URL
