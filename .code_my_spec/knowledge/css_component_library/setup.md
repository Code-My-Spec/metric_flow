# DaisyUI Setup and Component Patterns in MetricFlow

This document covers the complete DaisyUI setup as it exists in the project, the theme system
used for agency white-labeling, how CoreComponents integrate with DaisyUI class names, dark mode
configuration, and common component patterns for the dashboard UI.

---

## How DaisyUI Is Installed

MetricFlow uses the Tailwind v4 CSS-first plugin model. DaisyUI is **not installed via npm**.
Instead, the compiled DaisyUI plugin files are vendored directly into `assets/vendor/`:

```
assets/vendor/daisyui.js         — the Tailwind plugin (v4 CSS-in-JS format)
assets/vendor/daisyui-theme.js   — the theme plugin for defining custom themes
```

To update DaisyUI, fetch the latest releases directly from GitHub:

```sh
curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui.js
curl -sLO https://github.com/saadeghi/daisyui/releases/latest/download/daisyui-theme.js
# Move both files into assets/vendor/
```

There is no `tailwind.config.js` in this project. Tailwind v4 is configured entirely through
`assets/css/app.css` using CSS `@import`, `@plugin`, and `@source` directives.

---

## `assets/css/app.css` — The Full Configuration

```css
@import "tailwindcss" source(none);
@source "../css";
@source "../js";
@source "../../lib/metric_flow_web";

@plugin "../vendor/heroicons";

/* DaisyUI plugin — themes: false disables all built-in themes */
@plugin "../vendor/daisyui" {
  themes: false;
}

/* Each theme is registered with the daisyui-theme plugin */
@plugin "../vendor/daisyui-theme" {
  name: "dark";
  default: false;
  prefersdark: true;
  color-scheme: "dark";
  --color-base-100: oklch(30.33% 0.016 252.42);
  --color-base-200: oklch(25.26% 0.014 253.1);
  --color-base-300: oklch(20.15% 0.012 254.09);
  --color-base-content: oklch(97.807% 0.029 256.847);
  --color-primary: oklch(58% 0.233 277.117);
  --color-primary-content: oklch(96% 0.018 272.314);
  --color-secondary: oklch(58% 0.233 277.117);
  --color-secondary-content: oklch(96% 0.018 272.314);
  --color-accent: oklch(60% 0.25 292.717);
  --color-accent-content: oklch(96% 0.016 293.756);
  --color-neutral: oklch(37% 0.044 257.287);
  --color-neutral-content: oklch(98% 0.003 247.858);
  --color-info: oklch(58% 0.158 241.966);
  --color-info-content: oklch(97% 0.013 236.62);
  --color-success: oklch(60% 0.118 184.704);
  --color-success-content: oklch(98% 0.014 180.72);
  --color-warning: oklch(66% 0.179 58.318);
  --color-warning-content: oklch(98% 0.022 95.277);
  --color-error: oklch(58% 0.253 17.585);
  --color-error-content: oklch(96% 0.015 12.422);
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.5rem;
  --border: 1.5px;
  --depth: 1;
  --noise: 0;
}

@plugin "../vendor/daisyui-theme" {
  name: "light";
  default: true;
  prefersdark: false;
  color-scheme: "light";
  --color-base-100: oklch(98% 0 0);
  --color-base-200: oklch(96% 0.001 286.375);
  --color-base-300: oklch(92% 0.004 286.32);
  --color-base-content: oklch(21% 0.006 285.885);
  --color-primary: oklch(70% 0.213 47.604);
  --color-primary-content: oklch(98% 0.016 73.684);
  --color-secondary: oklch(55% 0.027 264.364);
  --color-secondary-content: oklch(98% 0.002 247.839);
  --color-accent: oklch(0% 0 0);
  --color-accent-content: oklch(100% 0 0);
  --color-neutral: oklch(44% 0.017 285.786);
  --color-neutral-content: oklch(98% 0 0);
  --color-info: oklch(62% 0.214 259.815);
  --color-info-content: oklch(97% 0.014 254.604);
  --color-success: oklch(70% 0.14 182.503);
  --color-success-content: oklch(98% 0.014 180.72);
  --color-warning: oklch(66% 0.179 58.318);
  --color-warning-content: oklch(98% 0.022 95.277);
  --color-error: oklch(58% 0.253 17.585);
  --color-error-content: oklch(96% 0.015 12.422);
  --radius-selector: 0.25rem;
  --radius-field: 0.25rem;
  --radius-box: 0.5rem;
  --border: 1.5px;
  --depth: 1;
  --noise: 0;
}

/* LiveView loading state variants */
@custom-variant phx-click-loading (.phx-click-loading&, .phx-click-loading &);
@custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
@custom-variant phx-change-loading (.phx-change-loading&, .phx-change-loading &);

/* Dark mode: target elements inside [data-theme=dark] */
@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));

/* Make LiveView wrapper divs transparent for layout */
[data-phx-session], [data-phx-teleported-src] { display: contents }
```

Key points:

- `themes: false` tells DaisyUI to skip all built-in themes. Only the themes defined via
  `@plugin "../vendor/daisyui-theme"` blocks are compiled into the output CSS.
- All color values use the oklch color space for perceptual uniformity.
- Adding a new theme means adding another `@plugin "../vendor/daisyui-theme" { name: "..." }`
  block directly in `app.css`.

---

## Theme System for Agency White-Labeling

### How `data-theme` Works

DaisyUI themes are activated by setting a `data-theme` attribute anywhere in the DOM. When set
on `<html>`, it applies to the entire page. The attribute value must match the `name:` declared
in a `@plugin "../vendor/daisyui-theme"` block.

```html
<html data-theme="light">   <!-- applies the "light" theme -->
<html data-theme="dark">    <!-- applies the "dark" theme -->
<html data-theme="acme">    <!-- applies a custom "acme" agency theme -->
```

DaisyUI converts every semantic color (`--color-primary`, `--color-base-100`, etc.) into scoped
CSS custom properties under `[data-theme="name"]`. All DaisyUI component classes (`btn`, `card`,
`badge`, etc.) reference those custom properties.

### Defining a Custom Agency Theme

To add a per-agency theme, add a new `@plugin "../vendor/daisyui-theme"` block to `app.css`:

```css
@plugin "../vendor/daisyui-theme" {
  name: "acme";
  default: false;
  prefersdark: false;
  color-scheme: "light";

  /* Override only what differs from the default — the theme plugin inherits the rest */
  --color-primary: oklch(55% 0.22 30);          /* Acme brand red */
  --color-primary-content: oklch(98% 0.01 30);
  --color-secondary: oklch(60% 0.15 145);       /* Acme brand green */
  --color-secondary-content: oklch(98% 0.01 145);
  --color-base-100: oklch(99% 0 0);
  --color-base-content: oklch(18% 0.005 285);
}
```

Use the DaisyUI theme generator to build custom palettes: https://daisyui.com/theme-generator/

### Applying Themes from LiveView Assigns

In `root.html.heex`, drive the `data-theme` attribute from a `@theme` assign:

```heex
<html lang="en" data-theme={assigns[:theme] || "light"}>
```

The theme assign is set in the LiveView router pipeline or a `on_mount` hook that reads the
agency's `WhiteLabelConfig`:

```elixir
# In a LiveView on_mount hook or in user_auth.ex
defp assign_theme(socket, scope) do
  theme =
    case scope do
      %{agency: %{white_label_config: %{theme: theme}}} when is_binary(theme) -> theme
      _ -> "light"
    end

  assign(socket, :theme, theme)
end
```

For user-controlled dark/light toggling (not agency-level), the project uses
`localStorage` and JavaScript rather than server assigns — see the Dark Mode section below.

### Scoped Themes Inside a Page

A `data-theme` attribute works at any level of the DOM, not just `<html>`. This can be used
to preview agency themes in a settings UI without reloading the page:

```heex
<div data-theme={@preview_theme} class="card bg-base-100 p-6 rounded-box">
  <p class="text-base-content">Preview of the "@preview_theme" theme</p>
  <button class="btn btn-primary">Primary Button</button>
</div>
```

---

## Dark Mode Configuration

### The `dark` Custom Variant

`app.css` defines a custom Tailwind variant for dark mode:

```css
@custom-variant dark (&:where([data-theme=dark], [data-theme=dark] *));
```

This variant targets elements that are inside `[data-theme=dark]`. Use it exactly like
Tailwind's built-in `dark:` prefix:

```heex
<p class="text-base-content dark:text-primary">
  Text that shifts color in dark mode
</p>
```

This pattern is preferred over Tailwind's `media: prefers-color-scheme` dark mode because
the project uses `data-theme` as the source of truth — driven by `localStorage` and the
user's explicit toggle.

### User-Controlled Theme Toggle

The theme toggle lives in `MetricFlowWeb.Layouts.theme_toggle/1`. It dispatches a
`phx:set-theme` custom event that the inline script in `root.html.heex` handles:

```html
<script>
  (() => {
    const setTheme = (theme) => {
      if (theme === "system") {
        localStorage.removeItem("phx:theme");
        document.documentElement.removeAttribute("data-theme");
      } else {
        localStorage.setItem("phx:theme", theme);
        document.documentElement.setAttribute("data-theme", theme);
      }
    };
    if (!document.documentElement.hasAttribute("data-theme")) {
      setTheme(localStorage.getItem("phx:theme") || "system");
    }
    window.addEventListener("storage", (e) =>
      e.key === "phx:theme" && setTheme(e.newValue || "system")
    );
    window.addEventListener("phx:set-theme", (e) =>
      setTheme(e.target.dataset.phxTheme)
    );
  })();
</script>
```

When `"system"` is selected, `data-theme` is removed from `<html>`. DaisyUI then falls back to
the theme whose `@plugin` block has `prefersdark: true` or `prefersdark: false` matched against
the OS `prefers-color-scheme` media query.

The toggle component renders three buttons — system, light, dark — and uses CSS attribute
selectors to highlight the active choice without any JavaScript state:

```heex
<div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
  <!-- Sliding indicator — CSS-driven, no JS -->
  <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100
              brightness-200 left-0 [[data-theme=light]_&]:left-1/3
              [[data-theme=dark]_&]:left-2/3 transition-[left]" />

  <button class="flex p-2 cursor-pointer w-1/3"
          phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
    <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
  </button>

  <button class="flex p-2 cursor-pointer w-1/3"
          phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light">
    <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
  </button>

  <button class="flex p-2 cursor-pointer w-1/3"
          phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark">
    <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
  </button>
</div>
```

The `[[data-theme=light]_&]:left-1/3` class is an arbitrary Tailwind variant that applies
`left: 33%` when any ancestor has `data-theme="light"`. This is a Tailwind v4 pattern.

---

## CoreComponents Integration with DaisyUI

`MetricFlowWeb.CoreComponents` maps directly onto DaisyUI semantic classes. The following
table shows what each component renders.

| Component | DaisyUI classes used |
|---|---|
| `<.flash kind={:info}>` | `toast toast-top toast-end`, `alert alert-info` |
| `<.flash kind={:error}>` | `toast toast-top toast-end`, `alert alert-error` |
| `<.button>` | `btn btn-primary btn-soft` (default) or `btn btn-primary` |
| `<.input type="text">` | `fieldset`, `label`, `input`, `input-error` |
| `<.input type="select">` | `fieldset`, `label`, `select`, `select-error` |
| `<.input type="textarea">` | `fieldset`, `label`, `textarea`, `textarea-error` |
| `<.input type="checkbox">` | `fieldset`, `label`, `checkbox checkbox-sm` |
| `<.table>` | `table table-zebra` |
| `<.list>` | `list`, `list-row`, `list-col-grow` |
| `<.header>` | plain Tailwind only |

### Overriding Component Classes

Every input component accepts a `class` attr that replaces the default DaisyUI class. Use this
to adjust sizing or variant:

```heex
<!-- Compact input -->
<.input field={@form[:name]} label="Name" class="input input-sm w-full" />

<!-- Ghost button -->
<.button class="btn btn-ghost">Cancel</.button>

<!-- Danger button -->
<.button class="btn btn-error">Delete</.button>
```

The `error_class` attr overrides the error state class independently:

```heex
<.input field={@form[:email]} class="input w-full" error_class="input-error input-bordered" />
```

### Form Layout Pattern

Forms use DaisyUI's `fieldset` element for spacing and the `label`/`label` (the DaisyUI label
component, not the HTML `<label>` element) for stacked layout. The `mb-2` on each `fieldset`
creates consistent vertical rhythm between fields:

```heex
<.form for={@form} phx-submit="save" phx-change="validate">
  <.input field={@form[:name]} type="text" label="Name" />
  <.input field={@form[:email]} type="email" label="Email" />
  <.input field={@form[:role]} type="select" label="Role"
          options={[{"Admin", "admin"}, {"Member", "member"}]} />
  <div class="flex gap-3 mt-4">
    <.button variant="primary" phx-disable-with="Saving...">Save</.button>
    <.button class="btn btn-ghost" navigate={~p"/settings"}>Cancel</.button>
  </div>
</.form>
```

The `phx-disable-with` attribute works naturally with DaisyUI buttons — LiveView adds a
`phx-submit-loading` class to the form during submission, and the `phx-submit-loading` custom
variant in `app.css` can dim the button:

```css
/* app.css — already present */
@custom-variant phx-submit-loading (.phx-submit-loading&, .phx-submit-loading &);
```

```heex
<.button variant="primary"
         class="btn btn-primary phx-submit-loading:opacity-60 phx-submit-loading:cursor-wait"
         phx-disable-with="Saving...">
  Save
</.button>
```

### The `divider` Component

DaisyUI's `divider` class is a horizontal rule with optional label text. Used in settings pages:

```heex
<div class="divider" />
<div class="divider">or</div>
```

---

## Common Component Patterns for Dashboards

### Metric Stat Card

Use `stat` inside a `stats` container for KPI displays. The design system uses JetBrains Mono
for numeric values (add `font-mono` to the figure):

```heex
<div class="stats stats-vertical lg:stats-horizontal shadow w-full">
  <div class="stat">
    <div class="stat-figure text-success">
      <.icon name="hero-arrow-trending-up" class="size-8" />
    </div>
    <div class="stat-title">Monthly Revenue</div>
    <div class="stat-value font-mono">$124,847</div>
    <div class="stat-desc text-success">+12.4% from last month</div>
  </div>

  <div class="stat">
    <div class="stat-figure text-primary">
      <.icon name="hero-users" class="size-8" />
    </div>
    <div class="stat-title">Active Users</div>
    <div class="stat-value font-mono">1,284</div>
    <div class="stat-desc text-base-content/60">Across all accounts</div>
  </div>

  <div class="stat">
    <div class="stat-figure text-error">
      <.icon name="hero-arrow-trending-down" class="size-8" />
    </div>
    <div class="stat-title">Churn Rate</div>
    <div class="stat-value font-mono text-error">3.2%</div>
    <div class="stat-desc text-error">-0.8% from last month</div>
  </div>
</div>
```

For trend indicators that match the design system colors:

```heex
<!-- Positive trend -->
<span class="font-mono text-success text-sm">+8.3%</span>

<!-- Negative trend -->
<span class="font-mono text-error text-sm">-2.1%</span>

<!-- Neutral / no change -->
<span class="font-mono text-base-content/50 text-sm">0.0%</span>
```

### Data Table

The CoreComponents `<.table>` component renders a `table table-zebra`. For dashboards, the table
often needs to be wrapped in an overflow container and given `table-pin-rows` for sticky headers:

```heex
<div class="overflow-x-auto rounded-box border border-base-300">
  <.table id="integrations" rows={@integrations}>
    <:col :let={i} label="Platform">{i.provider}</:col>
    <:col :let={i} label="Status">
      <.integration_status_badge integration={i} />
    </:col>
    <:col :let={i} label="Connected">
      {Calendar.strftime(i.inserted_at, "%b %d, %Y")}
    </:col>
    <:action :let={i}>
      <.button class="btn btn-ghost btn-xs" phx-click="sync" phx-value-id={i.id}>
        Sync
      </.button>
    </:action>
  </.table>
</div>
```

For a loading state overlay on the table during LiveView updates:

```heex
<div class="relative">
  <div class="phx-change-loading:opacity-50 transition-opacity">
    <!-- table here -->
  </div>
  <div class="phx-change-loading:flex hidden absolute inset-0 items-center justify-center">
    <span class="loading loading-spinner loading-md text-primary" />
  </div>
</div>
```

### Integration/Connection Card Grid

The integration index page currently uses plain Tailwind classes. The DaisyUI card pattern
is the intended approach for the production UI:

```heex
<div class="grid grid-cols-1 md:grid-cols-2 gap-4">
  <div :for={platform <- @supported_platforms}
       data-platform={platform.id}
       class="card card-border bg-base-100">
    <div class="card-body flex-row items-center gap-4 py-4 px-5">
      <!-- Platform icon -->
      <div class="bg-base-200 rounded-lg p-3 shrink-0">
        <.icon name={platform_icon(platform.id)} class="size-6 text-base-content/70" />
      </div>

      <div class="flex-1 min-w-0">
        <h3 class="card-title text-base">{platform.name}</h3>
        <p class="text-sm text-base-content/60">{platform_category_label(platform.category)}</p>
      </div>

      <%= if connected_platform?(@integrations, platform.id) do %>
        <div class="badge badge-success gap-1">
          <.icon name="hero-check-circle-micro" class="size-3" />
          Connected
        </div>
      <% else %>
        <.button class="btn btn-primary btn-sm" navigate={~p"/integrations/connect/#{platform.id}"}>
          Connect
        </.button>
      <% end %>
    </div>
  </div>
</div>
```

### Status Badges

Replace the raw color Tailwind classes currently in `IntegrationLive.Index` with semantic DaisyUI
badge classes:

```heex
<!-- Instead of class="text-green-600" / class="text-red-600" -->
<%= case sync_status(@integration, @syncing_ids) do %>
  <% "Active" -> %>
    <span class="badge badge-success badge-sm">Active</span>
  <% "Syncing" -> %>
    <span class="badge badge-info badge-sm gap-1">
      <span class="loading loading-spinner loading-xs" />
      Syncing
    </span>
  <% "Error" -> %>
    <span class="badge badge-error badge-sm">Error</span>
<% end %>
```

This approach uses DaisyUI's semantic colors (`badge-success`, `badge-error`) rather than
hardcoded Tailwind color classes, so status indicators automatically adapt to both the light
and dark themes.

### Modal

DaisyUI modals in a LiveView app work best with the HTML `<dialog>` element. The `modal` class
styles it; `modal-open` opens it. Control visibility through LiveView assigns rather than
JavaScript where possible:

```heex
<dialog class={["modal", @show_confirm && "modal-open"]}>
  <div class="modal-box">
    <h3 class="text-lg font-bold">Confirm Disconnect</h3>
    <p class="py-4 text-base-content/70">
      Historical data will remain but no new data will sync.
      Are you sure you want to disconnect?
    </p>
    <div class="modal-action">
      <button class="btn btn-error" phx-click="disconnect" phx-value-id={@pending_id}>
        Disconnect
      </button>
      <button class="btn btn-ghost" phx-click="cancel_disconnect">Cancel</button>
    </div>
  </div>
  <!-- Click backdrop to close -->
  <form method="dialog" class="modal-backdrop">
    <button phx-click="cancel_disconnect">close</button>
  </form>
</dialog>
```

In the LiveView, toggle `@show_confirm` with `handle_event`:

```elixir
def handle_event("confirm_disconnect", %{"id" => id}, socket) do
  {:noreply, assign(socket, show_confirm: true, pending_id: String.to_integer(id))}
end

def handle_event("cancel_disconnect", _params, socket) do
  {:noreply, assign(socket, show_confirm: false, pending_id: nil)}
end
```

### Navigation Sidebar (Dashboard Layout)

For the dashboard layout, the DaisyUI `drawer` pattern provides a responsive sidebar:

```heex
<div class="drawer lg:drawer-open">
  <input id="main-drawer" type="checkbox" class="drawer-toggle" />

  <!-- Page content -->
  <div class="drawer-content flex flex-col">
    <!-- Top bar (mobile only) -->
    <div class="navbar bg-base-100 lg:hidden border-b border-base-300">
      <label for="main-drawer" class="btn btn-square btn-ghost">
        <.icon name="hero-bars-3" class="size-5" />
      </label>
      <span class="font-bold ml-2">MetricFlow</span>
    </div>

    <!-- Main content area -->
    <main class="flex-1 p-6">
      {@inner_content}
    </main>
  </div>

  <!-- Sidebar -->
  <div class="drawer-side z-40">
    <label for="main-drawer" aria-label="close sidebar" class="drawer-overlay" />
    <aside class="bg-base-200 min-h-full w-64 p-4">
      <!-- Logo -->
      <div class="px-2 py-4 mb-4">
        <span class="text-xl font-bold">
          <span class="text-primary">Metric</span><span class="text-accent">Flow</span>
        </span>
      </div>

      <!-- Navigation menu -->
      <ul class="menu menu-sm w-full gap-1">
        <li>
          <.link navigate={~p"/dashboard"} class={nav_active?(@current_path, "/dashboard")}>
            <.icon name="hero-chart-bar" class="size-4" />
            Dashboard
          </.link>
        </li>
        <li>
          <.link navigate={~p"/integrations"} class={nav_active?(@current_path, "/integrations")}>
            <.icon name="hero-puzzle-piece" class="size-4" />
            Integrations
          </.link>
        </li>
        <li class="menu-title text-xs mt-4">Account</li>
        <li>
          <.link navigate={~p"/users/settings"} class={nav_active?(@current_path, "/users/settings")}>
            <.icon name="hero-cog-6-tooth" class="size-4" />
            Settings
          </.link>
        </li>
      </ul>
    </aside>
  </div>
</div>
```

The `nav_active?/2` helper returns `"active"` (a DaisyUI menu class) when the paths match:

```elixir
defp nav_active?(current_path, path) do
  if String.starts_with?(current_path, path), do: "active", else: ""
end
```

`lg:drawer-open` keeps the sidebar permanently visible on large screens and hidden (toggle-based)
on smaller screens, without any JavaScript.

---

## DaisyUI Color Variables Reference

When writing custom CSS or utility overrides that need to reference the current theme colors,
use the DaisyUI CSS custom properties rather than hardcoded oklch values:

| Variable | Purpose | Example use |
|---|---|---|
| `--color-primary` | Brand primary | `border-primary`, `text-primary` |
| `--color-base-100` | Page background | `bg-base-100` |
| `--color-base-200` | Card/sidebar background | `bg-base-200` |
| `--color-base-300` | Elevated surfaces, dividers | `bg-base-300`, `border-base-300` |
| `--color-base-content` | Body text | `text-base-content` |
| `--color-success` | Positive metrics, connected status | `text-success`, `badge-success` |
| `--color-warning` | Pending states, caution | `text-warning`, `badge-warning` |
| `--color-error` | Failures, disconnects, negative trends | `text-error`, `badge-error` |
| `--color-info` | Informational states, tips | `text-info`, `alert-info` |

Use opacity modifiers for secondary text — `text-base-content/70` is the preferred pattern over
`text-gray-500`, so secondary text automatically adapts to the active theme.

---

## The Design System Reference

A static HTML design system prototype lives at `docs/design/design_system.html`. It uses
DaisyUI v4 from CDN and defines a `metricflow` custom dark theme. Key visual characteristics
from the prototype that should inform production UI:

- Deep neutral dark background (`oklch(0.14 0.02 270)`)
- Semi-transparent card surfaces with `backdrop-filter: blur(16px)`
- Luminous indigo borders that glow on hover
- JetBrains Mono for all numeric metric values (`font-mono`)
- Aurora gradient background animation (for marketing pages, not dashboard)

The custom `metricflow` dark theme from the prototype uses the older DaisyUI v4 CSS variable
format (`--p`, `--s`, `--a`, etc.). The project's `app.css` uses the DaisyUI v5 format
(`--color-primary`, `--color-secondary`, `--color-accent`, etc.). When translating from the
prototype to production, map accordingly:

| Prototype (v4) | Production (v5) |
|---|---|
| `--p` | `--color-primary` |
| `--s` | `--color-secondary` |
| `--a` | `--color-accent` |
| `--b1` | `--color-base-100` |
| `--b2` | `--color-base-200` |
| `--b3` | `--color-base-300` |
| `--bc` | `--color-base-content` |
| `--su` | `--color-success` |
| `--wa` | `--color-warning` |
| `--er` | `--color-error` |
| `--in` | `--color-info` |
