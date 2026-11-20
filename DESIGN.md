# DESIGN.md — Anderson BI (MetricFlow)

The app should look like the Anderson BI Insights Hub mockup at
`.code_my_spec/design/anderson-bi-mockup.png`: a near-black navy page, a
slightly lighter navy sidebar, white text on a soft cyan→teal→gold→magenta
brand gradient, and soft rounded corners.

Every page follows this file. If something here conflicts with generic UI
advice elsewhere (AGENTS.md, Phoenix defaults, daisyUI), this file wins.

## Tokens

The tokens are defined once, as the single daisyUI theme `dark` in
`assets/css/app.css`. There is **no light theme** and no
`prefers-color-scheme` switch: the app looks the same whatever the OS is
set to. `<html>` carries `data-theme="dark"`.

| Token (Tailwind class / CSS var)            | Value           | Used for                             |
|---------------------------------------------|-----------------|--------------------------------------|
| `base-100` / `--brand-page`                 | `#090f1d`       | page background                      |
| `base-200` / `--brand-sidebar`              | `#0d1323`       | sidebar, panels, cards               |
| `base-300`                                  | `#171e2f`       | hover and raised surfaces            |
| `base-content` / `--brand-text`             | `#f5f6fa`       | body text                            |
| `--brand-muted`                             | `#c0c5d4`       | secondary nav labels, captions       |
| `neutral` / `--brand-line`                  | `#354055`       | borders and dividers                 |
| `primary` (cyan)                            | `#0baac8`       | start of the brand gradient, links   |
| `secondary` (teal)                          | `#3dc0aa`       | success accent, mid gradient         |
| `accent` (gold)                             | `#e4b76a`       | warning accent, gradient highlight   |
| `error` (magenta)                           | `#d53f60`       | destructive actions, errors          |
| `--brand-gradient`                          | `linear-gradient(105deg, #0baac8 0%, #3dc0aa 35%, #e4b76a 70%, #d53f60 100%)` | New Chat, Register, Send |
| suggestion card green  (`--accent-green`)   | `#2c896c`       | Business Performance card border     |
| suggestion card blue   (`--accent-blue`)    | `#2a7aa8`       | Customer Insights card border        |
| suggestion card gold   (`--accent-gold`)    | `#967442`       | Marketing Effectiveness card border  |
| suggestion card purple (`--accent-purple`)  | `#765a9e`       | Financial Health card border         |
| font                                        | Inter, falling back to system sans | everything              |
| radius `rounded-box` (`--radius-box`)       | 12px            | buttons, cards, nav pills            |
| radius for the composer                     | 24px            | the AI chat composer only            |

## Rules

1. **Only theme tokens.** Use `bg-base-100`, `text-base-content`,
   `bg-base-200`, `border-neutral`, `btn-brand-gradient` and so on. Never
   write a hard-coded colour (`#0baac8`, `rgb(...)`, `bg-blue-900`,
   `text-gray-600`, inline `style="color: ..."`) in a template.
2. **Only theme radii.** Use `rounded-box` for boxes and `rounded-full`
   for circles. The composer is the one exception: it uses the
   24px composer radius.
3. **Phone first, 390px.** Design every page for a 390px-wide phone, then
   widen with `sm:` / `md:` / `lg:`. Nothing may scroll sideways at 390px:
   rows that can overflow use `flex-wrap`, long text (emails, titles) uses
   `break-words` or `break-all`, flex children that hold text get
   `min-w-0`, images get `max-w-full`, tables are avoided or wrapped in
   `overflow-x-auto` *inside* their own panel. The main column carries
   `overflow-x-hidden`.
4. **Headings.** One `h1` per page. Headings are `text-base-content`;
   accent them with `text-primary` or the brand gradient only when the
   mockup does.
5. **Keep every `id` and `data-*`.** Tests use them. In particular keep
   `data-role="default-logo"`, `data-role="agency-logo"` and
   `data-role="current-account-name"`.

## Shell

### Sidebar (in `Layouts.app`)

Left rail on `lg:`, drawer behind `#sidebar-toggle` on a phone. In order:

1. The gradient logo, `/images/anderson-bi-logo.png` (never hotlinked),
   or the agency white-label logo when one is configured. The default
   carries `data-role="default-logo"`; the agency one carries
   `data-role="agency-logo"`.
2. A gradient **New Chat** button that links to `/app/chat?new=1`.
3. Flat primary nav: AI Chat (`/app/chat`), All Data (`/app/dashboard`),
   Correlations, Integrations, Reports.
4. A thin divider (`border-neutral`).
5. A quieter secondary group for the rest of today's links (Dashboards,
   Insights, Goals, Account pages). The Agency group only when the
   active account's `type` is `:agency`.
6. **Recent conversations** — the active account's five most recent chat
   sessions, each linking to `/app/chat/:id`. The hook
   `MetricFlowWeb.Hooks.ActiveAccountHook` assigns them as
   `@recent_chat_sessions`.
7. At the bottom, the **account picker**: shows the active account name
   (wrapper `data-role="account-picker"`, name span
   `data-role="current-account-name"`) and links to `/app/accounts`.

### Top bar (in `Layouts.app`)

A 64px bar with, left to right: the hamburger (`data-role="open-sidebar"`,
phone only), a spacer, a round **Help** link, and the **avatar menu**
(`data-role="avatar-menu"`) that opens User settings and Log out. No
notification bell: there is no notifications feature.

### Public header and footer (in `Layouts.content`)

Same colours and logo as the app shell. Home, login and register use
this layout.

## Components

### Primary (gradient) button

`btn-brand-gradient rounded-box px-4 py-2`. Used for the main action in
the shell: New Chat, Register, Send. One primary button per form or card.
Full width on a phone (`w-full sm:w-auto`).

### Secondary button

`rounded-box border border-neutral bg-base-200 px-4 py-2 text-base-content
hover:bg-base-300`. Used for the second action (Cancel, Back).

### Card

`bg-base-200 border border-neutral rounded-box p-4` panel with no shadow.
Use for a list item, a form wrapper, a stat.

### Suggestion card (the four coloured prompt tiles)

`rounded-box border px-5 py-4 min-h-[160px]` plus one of `accent-green`,
`accent-blue`, `accent-gold`, `accent-purple`. The icon sits in a
`rounded-box` square tinted to match; the title is `font-semibold`; the
body is `text-base-content/80`.

### Composer (the AI chat input)

One row: `flex items-center gap-3 min-h-[80px] px-6 py-3
rounded-[24px] border border-transparent bg-base-200`, with a brand-gradient
border (`background: linear-gradient(...) border-box`). The textarea is
`bg-transparent border-0 text-base-content`; the send button is
`btn-brand-gradient rounded-box`.

### Form

- Inside a `bg-base-200 border border-neutral rounded-box p-4` panel, one
  column at 390px.
- Labels above inputs, `font-semibold text-base-content`.
- Inputs use the `<.input>` component: `bg-base-100 border-neutral
  rounded-box`, full width.
- Errors under the field in `text-error`.
- The primary (gradient) button at the bottom, full width on a phone.

### Empty state

When a list has nothing to show: a `bg-base-200 border border-neutral
rounded-box p-6 text-center` panel with one short heading line, one line
of body text, and at most one primary button to act on it. Keep the
list's existing `id` on the container.

### Alerts

`alert` with `alert-info`, `alert-warning` or `alert-error`,
`rounded-box`, full width of the content column.

## Design pass

One page per pass, the persona for that page on a phone first. Read
`.code_my_spec/personas/` before the first one.

1. Prove the browser works (`agent-browser open` on the running app) before editing. If it does not, stop and say so.
2. Screenshot the page at 390 and 1440 wide, on the sample data (`mix run priv/repo/seeds.exs`), into the work's evidence folder.
3. Read the data the page shows. For every element ask: does it vary, does anyone act on it, would they miss it?
4. Rank the problems by what each costs the person using the page. Fix the top three. Structure before styling.
5. Edit the HEEx directly. Keep every `id` and `data-*`. Only the tokens and components above.
6. Screenshot again, same widths. Run the page's tests.
7. Commit with the trailer `Design-Pass: <path of the page's file>`, one per page file, and say in the message what the page lost.

A page is due a pass when the last commit that touched its file has no such trailer:

    git log -1 --format=%B -- lib/metric_flow_web/live/ai_live/chat.ex | grep -q '^Design-Pass:' || echo due

### What a pass must check and say (from ten audited passes on another app)

- `git status --short` first: a run that died leaves edits. Keep them only if good, and say so.
- A LiveView draws a placeholder until its socket connects. Before each screenshot wait until `window.liveSocket && liveSocket.isConnected()`, and read back `location.pathname`: a shot of the wrong page passes for the right one.
- At 390, `document.documentElement.scrollWidth` must equal the viewport's width.
- Take the before shot before editing. If you forgot: put the committed file back (`git stash` is not allowed; copy your edit aside), shoot, restore.
- A pass that only polishes while the page's biggest problem stands has failed. Structure beats styling: an index is one row or card per thing linking to it; detail lives on the show page; a form is its own page.
- Before removing any markup, grep `test/` for its `id` and `data-*`, and run every file that matches. Fold a control a test clicks into a closed `<details>`; do not delete it.
- Tokens own how a thing looks, components own its markup and its variants (named by meaning, never by colour), pages own content and layout only. A pattern used twice becomes a function component.
- The message says: the ranked problems, what the page lost and whether that is right, states the sample data could not show and how they were checked, and under "For the owner to decide" any default or behaviour the pass changed, with the evidence.
- Lead with what the person came for. Terse, plain words, no decoration. Check the empty and the long case.
