# Cloudflare Tunnel (Dev Tunneling)

## Auth Type

api_token

## Required Credentials

- `CLOUDFLARE_TUNNEL_SECRET` — Tunnel secret for named Cloudflare tunnel (dev only)

## Verify Script

`.code_my_spec/qa/scripts/verify_cloudflare_tunnel.sh`

## Status

verified

## Notes

- Cloudflare Zero Trust dashboard: https://one.dash.cloudflare.com/
- Development-only — provides `dev.metric-flow.app` → localhost:4070
- Requires cloudflared installed locally
- Alternative to ngrok for OAuth callback testing
