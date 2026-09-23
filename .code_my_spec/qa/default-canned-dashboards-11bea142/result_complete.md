# QA Result — Story 444: Default Canned Dashboards

## Status

pass

## Scenarios

### Scenario 1 — Page loads for authenticated user

**Result: pass**

Navigated to `http://localhost:4070/dashboards` after login. Page loaded without redirect. H1 "Dashboards" and subtitle "Your saved views and system dashboards" were both present.

Evidence: `screenshots/scenario_1_page_loads.png`

---

### Scenario 2 — Canned dashboards section is visible

**Result: pass**

The `[data-role="canned-dashboards"]` section was present with the heading "System Dashboards". Three cards with `data-built-in="true"` were rendered. Each card showed a "Built-in" badge and a "View" button.

Evidence: `screenshots/scenario_2_canned_dashboards_section.png`

---

### Scenario 3 — Marketing Overview template is displayed

**Result: pass**

A card with `p.font-semibold` text "Marketing Overview" was visible inside the canned dashboards section.

Evidence: `screenshots/scenario_3_marketing_overview.png`

---

### Scenario 4 — Revenue Analysis template is displayed

**Result: pass**

A card with `p.font-semibold` text "Revenue Analysis" was visible inside the canned dashboards section.

Evidence: `screenshots/scenario_4_revenue_analysis.png`

---

### Scenario 5 — Platform Comparison template is displayed

**Result: pass**

A card with `p.font-semibold` text "Platform Comparison" was visible inside the canned dashboards section.

Evidence: `screenshots/scenario_5_platform_comparison.png`

---

### Scenario 6 — Multiple canned templates listed (template grid)

**Result: pass**

`browser_find_all` returned 3 elements matching `[data-role="dashboard-card"][data-built-in="true"]`. All three named templates (Marketing Overview, Platform Comparison, Revenue Analysis) appeared in the grid.

Evidence: `screenshots/scenario_6_multiple_templates.png`

---

### Scenario 7 — Unauthenticated user cannot access dashboards

**Result: pass**

Launched a fresh browser session (no cookies). Navigated directly to `http://localhost:4070/dashboards`. The browser was redirected to `http://localhost:4070/users/log-in`. Dashboard content was not accessible.

Evidence: `screenshots/scenario_7_unauthenticated_redirect.png`

---

### Scenario 8 — User dashboards section is present

**Result: pass**

After login, `[data-role="user-dashboards"]` was present with the heading "My Dashboards". Since `qa@example.com` has no user-owned dashboards, `[data-role="empty-user-dashboards"]` was shown with text "No dashboards yet" and a "Create your first dashboard" link.

Evidence: `screenshots/scenario_8_user_dashboards_section.png`

---

### Scenario 9 — "New Dashboard" button is present

**Result: pass**

`[data-role="new-dashboard-btn"]` with text "New Dashboard" was present. Its `href` attribute is `/dashboards/new`.

Evidence: `screenshots/scenario_9_new_dashboard_btn.png`

---

## Evidence

- `.code_my_spec/qa/444/screenshots/scenario_1_page_loads.png`
- `.code_my_spec/qa/444/screenshots/scenario_2_canned_dashboards_section.png`
- `.code_my_spec/qa/444/screenshots/scenario_3_marketing_overview.png`
- `.code_my_spec/qa/444/screenshots/scenario_4_revenue_analysis.png`
- `.code_my_spec/qa/444/screenshots/scenario_5_platform_comparison.png`
- `.code_my_spec/qa/444/screenshots/scenario_6_multiple_templates.png`
- `.code_my_spec/qa/444/screenshots/scenario_7_unauthenticated_redirect.png`
- `.code_my_spec/qa/444/screenshots/scenario_8_user_dashboards_section.png`
- `.code_my_spec/qa/444/screenshots/scenario_9_new_dashboard_btn.png`

## Issues

None
