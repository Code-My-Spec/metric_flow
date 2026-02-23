# DaisyUI

## Status

Accepted

## Context

MetricFlow uses Tailwind CSS for styling and needs semantic component classes for
dashboard UI elements (cards, tables, stats, modals, navigation). Agency white-label
theming requires a theme system that supports per-agency color customization.

See `css_component_library.md` for the full evaluation of component library options.

## Decision

**DaisyUI as the Tailwind CSS component plugin.**

DaisyUI adds semantic class names (`btn`, `card`, `table`, `modal`, `stat`) on top of
Tailwind utilities. Its theme system uses CSS custom properties that can be overridden
per agency, enabling white-label theming via the `data-theme` HTML attribute.

Key reasons:
- Pure CSS plugin — no JavaScript runtime, ideal for LiveView
- 30+ built-in themes with custom theme support
- Theme switching via `data-theme` attribute driven by server assigns
- Components cover the dashboard UI vocabulary

## Consequences

- Install via `npm install --prefix assets daisyui@latest`
- Configure themes in `assets/tailwind.config.js`
- CoreComponents use DaisyUI class names for consistent styling
- Agency white-label colors map to DaisyUI theme CSS variables
- See `css_component_library.md` for detailed setup and trade-offs
