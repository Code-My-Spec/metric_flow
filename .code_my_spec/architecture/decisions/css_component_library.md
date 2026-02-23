# CSS Component Library

## Status

Accepted

## Context

MetricFlow is a dashboard-heavy analytics SaaS with:

- Data tables, metric cards, chart containers, and stat summaries
- Form-heavy settings pages (account, agency, integration configuration)
- Navigation sidebars and responsive layouts
- Agency white-label theming (custom colors, logos per agency)
- Dark mode support expected by dashboard users

The project already uses Tailwind CSS (via the `tailwind` Mix package) and Heroicons v2.2.0.
Phoenix CoreComponents provide basic form inputs, tables, and flash messages.

## Options Considered

### DaisyUI

Tailwind CSS component library that adds semantic class names (`btn`, `card`, `table`, `modal`)
on top of Tailwind utility classes. Ships with 30+ built-in themes and supports custom theming
via CSS variables — directly enabling agency white-label color customization.

- Installed as a Tailwind plugin (no JS runtime, no npm package beyond the plugin)
- 35K+ GitHub stars, actively maintained
- Theme switching via a `data-theme` attribute on `<html>` — trivial to set from server assigns

### Petal Components

Phoenix LiveView-specific component library with HEEx templates. Provides Phoenix-native
components with LiveView event handling built in.

- Smaller community (2K stars)
- Tighter LiveView integration but adds an Elixir dependency
- Theme customization is more limited than DaisyUI

### Custom CoreComponents Only

Extend the Phoenix-generated CoreComponents with project-specific components.

- Maximum control, zero dependencies
- Significant upfront work to build card, stat, table, navigation, and modal components
- No built-in theme system for white-labeling

## Decision

**Tailwind CSS + DaisyUI.**

DaisyUI is selected because:

1. **White-label theming** — DaisyUI's theme system uses CSS custom properties (`--p`, `--s`,
   `--a`, etc.) that can be overridden per agency. Setting `data-theme` on the root element
   switches the entire UI. Custom themes can be defined in `tailwind.config.js` and selected
   dynamically based on the `WhiteLabelConfig` for the current agency subdomain.

2. **Zero JS overhead** — DaisyUI is a pure CSS/Tailwind plugin. It adds no JavaScript runtime,
   which is ideal for a LiveView app where interactions are server-driven.

3. **Component coverage** — Cards, stats, tables, navigation drawers, modals, badges, and
   form inputs cover the dashboard UI vocabulary with semantic class names.

4. **Dark mode** — Built-in dark theme that works with the theme system.

5. **Tailwind compatibility** — All DaisyUI components accept standard Tailwind utility classes
   for customization, so CoreComponents can use DaisyUI classes directly.

## Consequences

**Setup actions:**

1. Install DaisyUI: `npm install --prefix assets daisyui@latest`
2. Add to `assets/tailwind.config.js`:
   ```js
   plugins: [require("daisyui")],
   daisyui: {
     themes: ["light", "dark", /* custom agency themes */],
   }
   ```
3. Update `CoreComponents` to use DaisyUI class names where appropriate (e.g., `btn`,
   `input`, `table`, `card`)
4. Add `data-theme` attribute to the root `<html>` tag in `root.html.heex`, driven by
   a `@theme` assign that defaults to `"light"` and is overridden by agency `WhiteLabelConfig`

**Trade-offs accepted:**

- DaisyUI's semantic classes add a layer on top of Tailwind — developers need to understand
  both DaisyUI component classes and Tailwind utilities
- Custom agency themes require defining color palettes in `tailwind.config.js` or dynamically
  via CSS custom properties at runtime
- DaisyUI version upgrades may introduce breaking class name changes (mitigated by pinning the
  version)
