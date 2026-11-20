# Evidence — sync-history-design-pass

Four full-page PNGs of `/app/integrations/sync-history` captured from this
worktree's own dev server against the seeded `metric_flow_pddp` database
(`priv/repo/seeds.exs`). The seeded user `client@example.com` (password
`hello world!`) owns the Anderson Retail Co. account and has no sync
history rows yet, so the page renders the empty state — the same state
the prior `provider-dashboard-design-pass` observed for this account.
That state still exercises every structural token change on the page:
the schedule Card, the filter tabs row, the date-range line, and the
empty-history Card all land in one frame at each width.

| File              | Viewport  | State  | What it shows |
|-------------------|-----------|--------|---------------|
| `before-390.png`  | 390x844   | before | Pre-pass phone page. The Automated Sync Schedule panel and the "No sync history yet" panel are both drawn with `mf-card` (an undefined class — no border, no background), so the cards read as loose text against the page background. Headings use the default sizing with no `min-w-0`/`break-words` guard. `document.documentElement.scrollWidth === 390` and `!!document.querySelector('.mf-card') === true`. |
| `before-1440.png` | 1440x900  | before | Same pre-pass markup on desktop — the Card chrome is still invisible, filter tabs sit flush against the schedule panel, and the empty-history panel has no border, same undefined `mf-card` wrapper. |
| `after-390.png`   | 390x844   | after  | Post-pass phone page. The schedule panel, empty-history panel and every history row carry the DESIGN.md Card tokens (`rounded-box border border-neutral bg-base-200`). Headings carry `min-w-0 break-words`. The main column wraps in `overflow-x-hidden`. `document.documentElement.scrollWidth === 390` and `!!document.querySelector('.mf-card') === false`. |
| `after-1440.png`  | 1440x900  | after  | Same post-pass markup on desktop: Card tokens applied, filter tabs sit above the empty-history Card with the new border, and the Provider error details `<details>` block (used on failed persisted rows) switches from `rounded-lg border-base-content/15` to `rounded-box border-neutral`. |

## Capture environment

- Dev server: `DATABASE_NAME=metric_flow_pddp PORT=4094 MIX_ENV=dev mix phx.server`,
  against the pre-seeded `metric_flow_pddp` database (`mix run
  priv/repo/seeds.exs` had been applied in a prior pass; this worktree
  reused the same DB so screenshots are on the committed seed script).
- `agent-browser` (headless Chromium) drove the login flow (`client@example.com`
  / `hello world!`) and navigated to `/app/integrations/sync-history`.
  Before each screenshot the driver read back
  `window.liveSocket && liveSocket.isConnected()` (true all four times),
  `location.pathname` (`/app/integrations/sync-history` all four times),
  `document.documentElement.scrollWidth` (390 at the 390 viewport, 1440
  at the 1440 viewport), and `!!document.querySelector('.mf-card')`
  (true before both before-shots, false before both after-shots).
- The before shots were captured after `git checkout HEAD --
  lib/metric_flow_web/live/integration_live/sync_history.ex` restored
  the issue-as-handed-in file (commit `8b155fb9`) and the dev server's
  live reload re-rendered the old markup. The file was restored to the
  post-pass edit (a copy stashed at `tmp/sync_history_after.ex`) before
  the two after shots.

## How it was checked

- `MIX_ENV=test mix test test/metric_flow_web/live/integration_live/sync_history_test.exs`
  passes 14 tests, including the two new ones under the
  `"failed syncs are listed before successful ones"` describe:
  - `persisted failed row appears before a newer persisted success row`
    seeds an older failed persisted entry and a newer successful one,
    then asserts the failed row renders before the successful row in
    the rendered HTML. Under the pre-pass ordering (repository
    `order_by desc: completed_at`) the newer success would come first,
    so this fails without the design pass.
  - `a live sync_failed event sits above a prior persisted success`
    sends a `:sync_failed` broadcast against a page that already shows a
    persisted success and asserts the failed row renders before the
    success row, which also fails without the failed-first partition.
- `MIX_ENV=test mix spex test/spex/16_sync_status_and_history` passes
  all 14 criteria, so the sync status & history spex suite still holds.
