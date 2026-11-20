# Evidence — integrations-index-design-pass

This pass was performed inside a headless coder environment that has no
browser access, so before/after screenshots at 390px and 1440px on the
seeded Anderson Retail Co. account could not be captured as part of this
commit.

To take them against this worktree:

1. Reseed: `MIX_ENV=dev mix ecto.reset && mix run priv/repo/seeds.exs`
2. Start the dev server: `mix phx.server` (port 4000).
3. Log in as `jordan@andersonretail.example`
   (the seeded Anderson Retail Co. client); open `/app/integrations`.
4. For each width in `[390, 1440]`:
   - Set the viewport to that width.
   - Wait for `window.liveSocket && liveSocket.isConnected()` and read back
     `location.pathname` to confirm the page.
   - Assert `document.documentElement.scrollWidth === innerWidth` at 390.
   - Save PNG as `after-{390,1440}.png`.

Before shots at the same widths come from the hand-in commit
`55ab6dbf issue integrations-index-design-pass: the issue as handed in`
(`before-{390,1440}.png`).

## What the pass changed

- Reordered providers so anything that needs attention (`:reconnect`,
  `:needs_selection`, `:not_connected`) renders before anything already
  `:done`.
- One card per provider, with a provider-level status badge and one next
  action at the top; per-product controls (sync, change, disconnect,
  reconnect-one-product) fold into a closed `<details>` on the same card
  so a Jordan-style client sees one line of answer per sign-in instead of
  a nested list.
- Cards use the DESIGN.md Card spec (`bg-base-200 border-neutral
  rounded-box p-4`); dividers switch from `base-300` to `neutral`; the
  main column carries `overflow-x-hidden`.

All existing `id` and `data-*` attributes on the page —
`connection-group-<key>`, `data-role="integrations-list"`,
`data-role="available-platforms-list"`, `data-platform=<key>`,
`data-status`, `data-role="integration-card"` /
`"integration-platform-name"` / `"integration-row"` /
`"integration-selected-accounts"` / `"integration-sync-status"` /
`"integration-connected-date"` / `"integration-detail-link"` /
`"edit-integration-accounts"` / `"reconnect-integration"` /
`"disconnect-integration"` / `"last-sync-at"` / `"next-sync-at"`,
`id="setup-data-sources"` / `"group-action-<key>"` / `"disconnect-google"`,
and the disconnect modal roles — are preserved.
