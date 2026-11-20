# Evidence — integrations-index-design-pass

Four full-page PNGs at 390px and 1440px of the /app/integrations page,
captured against the seeded Anderson Retail Co. account (owner
`client@example.com` from `priv/repo/seeds.exs`, password `hello world!`):

| File               | Viewport | Full page size | What it shows |
|--------------------|----------|----------------|---------------|
| before-390.png     | 390x844  | 390 x 1850     | Pre-pass index page on a phone — every provider expanded with its product rows and available-platforms list open, Google sits above the three not-connected sign-ins. |
| before-1440.png    | 1440x900 | 1440 x 1158    | Pre-pass index page on desktop — same four providers, each as a long section with inner dividers. |
| after-390.png      | 390x844  | 390 x  968     | Post-pass page on a phone — one card per provider, the three needs-attention providers before the connected Google card, per-product controls folded into the card's closed `<details>`. |
| after-1440.png     | 1440x900 | 1440 x  900    | Post-pass page on desktop — same card layout, problems-first order, per-card next-action button on the right. |

## Capture environment

- The dev server from this worktree, started with
  `PORT=<port> MIX_ENV=dev mix phx.server`, against the shared seeded
  `metric_flow_dev` database.
- Playwright 1.65 (from `assets/package.json`) driving headless Chromium.
- For every shot the driver script waited for `window.liveSocket &&
  liveSocket.isConnected()` before screenshotting and asserted
  `location.pathname === '/app/integrations'`.
- At 390 the script also recorded `document.documentElement.scrollWidth`
  and `window.innerWidth`: both read 390 for the after shot, confirming
  no sideways scroll on a phone.

Before shots were captured against the pre-fix file brought back with
`git show 55ab6dbf:lib/metric_flow_web/live/integration_live/index.ex`
and restored with `git checkout --` afterwards.
