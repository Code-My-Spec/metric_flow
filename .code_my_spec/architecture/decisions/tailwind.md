# Tailwind CSS

## Status

Accepted

## Context

MetricFlow needs a CSS approach for styling the dashboard UI. The project uses Phoenix 1.8
which ships with Tailwind CSS integration via the `tailwind` Mix package.

## Options Considered

### Tailwind CSS 3.x

Utility-first CSS framework that generates only the CSS classes used in templates.
Ships with Phoenix 1.8 by default.

- Zero-runtime — CSS is generated at build time via the Tailwind CLI
- Utility classes applied directly in HEEx templates
- Responsive design via breakpoint prefixes (`md:`, `lg:`)
- Customizable via `tailwind.config.js` — colors, spacing, fonts

### Bootstrap

Component-based CSS framework with pre-built UI components.

- Opinionated component styles harder to customize for white-label theming
- Larger CSS bundle — includes unused component styles
- JavaScript dependency for interactive components (dropdowns, modals)

### Vanilla CSS / CSS Modules

Custom stylesheets without a framework.

- Maximum control but significant effort for responsive layouts
- No design system consistency without manual discipline

## Decision

**Tailwind CSS via the `tailwind` Mix package (~> 0.3).**

Tailwind is the Phoenix default and provides the utility-first approach needed for
rapid UI development. It pairs with DaisyUI for semantic component classes (see
`css_component_library.md`) and supports the white-label theming requirement through
CSS custom properties.

## Consequences

- Styles are co-located with markup in HEEx templates — no separate CSS files for components
- The `tailwind` Mix package handles CLI installation and build integration
- Asset builds run via `mix assets.build` (development) and `mix assets.deploy` (production)
- Custom design tokens (colors, fonts) are defined in `assets/tailwind.config.js`
