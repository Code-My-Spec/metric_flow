# Design Review

## Overview

Reviewed MetricFlowWeb.DashboardLive context with 3 child LiveViews: Show, Index, and Editor. The architecture is sound with clear separation between viewing, listing, and editing dashboards.

## Architecture

- Clean separation of concerns: Show renders dashboards, Index lists them, Editor creates/edits them
- All three LiveViews depend solely on MetricFlow.Dashboards — single context dependency keeps coupling minimal
- Show handles two routes (`/dashboard` for default canned dashboard, `/dashboards/:id` for specific) which is appropriate for a dual-purpose view
- Editor handles `:new` and `:edit` live actions with shared UI logic — standard Phoenix pattern
- No shared LiveComponents needed; each view is self-contained with distinct interaction patterns

## Integration

- Index links to Show (`/dashboards/:id`) for viewing and Editor (`/dashboards/:id/edit`) for editing
- Index links to Editor (`/dashboards/new`) for creation
- Editor redirects to Show on successful save, creating a natural create → view workflow
- Show links to `/integrations` in onboarding prompt and `/chat` and `/insights` for AI features
- All views scope data via `current_scope` for multi-tenant isolation
- Canned vs user dashboards distinguished by `built_in` flag; Index prevents delete on canned dashboards

## Conclusion

The DashboardLive context is ready for implementation. All dependencies are verified, specs are consistent, and no issues were found.
