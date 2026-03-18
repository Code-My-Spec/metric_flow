# QA Result — Story 453: Agency White-label Configuration

## Status

pass

## Scenarios

Testing conducted via vibium MCP browser tools against `http://localhost:4070`. Auth user: `qa@example.com` / `hello world!` (owner of "QA Test Account", type=team). Seeds were in place from prior runs — login worked on first attempt.

This is a re-run following the fix for issue `qa-453-white_label_config_cannot_be_updated_via_`: the `white_label_value/3` helper in `lib/metric_flow_web/live/agency_live/settings.ex` was updated to prefer form params when non-empty, falling back to the saved config only when the form param is empty. All 13 scenarios now pass.

### Scenario 1 — White-Label Branding section is visible (criterion 4152, 4153, 4154)

**Result: pass**

Navigated to `http://localhost:4070/accounts/settings`. Verified:

- "White-Label Branding" heading is present in `[data-role="agency-white-label"]`
- `#white-label-form` is present
- `input[name='white_label[logo_url]']` is present
- `input[name='white_label[primary_color]']` is present
- `input[name='white_label[secondary_color]']` is present
- `input[name='white_label[subdomain]']` is present
- Helper text "Lowercase letters, numbers, and hyphens only (3–63 characters)" is visible

Evidence: `.code_my_spec/qa/453/screenshots/s1_white_label_section.png`

### Scenario 2 — Save with PNG logo URL (criterion 4152)

**Result: pass**

Reset to nil config state, then filled all four fields (subdomain `agency-png-test`, logo URL `https://cdn.example.com/logo.png`, primary `#FF5733`, secondary `#3498DB`) and submitted via `#white-label-form button[type="submit"]`. Flash "White-label settings saved" appeared. All four values are correctly pre-filled in the form inputs after save. Reset to Default button is visible.

Note: the flash text is "White-label settings saved" (not "White-label branding saved successfully" as the brief noted may differ from spec). This is a pre-existing INFO-level discrepancy.

Evidence: `.code_my_spec/qa/453/screenshots/s2_save_png_logo_url.png`

### Scenario 3 — Save with JPG logo URL — bug fix verified (criterion 4152)

**Result: pass**

This scenario directly tests the fix for the HIGH bug reported in the previous QA run. Config was already saved with `logo.png`. Navigated fresh to `/accounts/settings`, filled `logo_url` with `https://cdn.example.com/brand-logo.jpg`, then filled `subdomain` with `agency-jpg-test` (triggering a phx-change event that previously would have overwritten the logo URL field).

After phx-change fired: HTML inspection confirmed `value="https://cdn.example.com/brand-logo.jpg"` was retained in the logo URL input — the bug is fixed.

Submitted form; flash "White-label settings saved" appeared; HTML inspection confirmed both `subdomain=agency-jpg-test` and `logo_url=https://cdn.example.com/brand-logo.jpg` are pre-filled after save.

Evidence: `.code_my_spec/qa/453/screenshots/s3_jpg_url_retained_after_phx_change.png`, `.code_my_spec/qa/453/screenshots/s3_save_jpg_logo_url.png`

### Scenario 4 — Save with SVG logo URL (criterion 4152)

**Result: pass**

Reset to nil config state, filled all four fields (subdomain `agency-svg-test`, logo URL `https://cdn.example.com/vector-logo.svg`, primary `#AA1122`, secondary `#334455`) and submitted. Flash "White-label settings saved" appeared. SVG URL `https://cdn.example.com/vector-logo.svg` is pre-filled in input after save.

Evidence: `.code_my_spec/qa/453/screenshots/s4_save_svg_logo_url.png`

### Scenario 5 — Save custom color scheme (criterion 4153)

**Result: pass**

Reset to nil config state, filled subdomain `agency-color-test`, primary color `#3498DB`, secondary color `#2ECC71` (logo URL empty) and submitted. Flash "White-label settings saved" appeared. Both color values `#3498DB` and `#2ECC71` are pre-filled in inputs after save.

Evidence: `.code_my_spec/qa/453/screenshots/s5_save_color_scheme.png`

### Scenario 6 — Real-time preview before saving (criterion 4155)

**Result: pass**

Reset to nil config state. Typed `#E74C3C` into primary color input and pressed Tab to trigger phx-change. `[data-role="white-label-preview"]` panel appeared immediately showing `#E74C3C`. No save flash was present (only the prior reset flash remained). Then typed `#9B59B6` into secondary color input and pressed Tab — preview updated to show both `#E74C3C` and `#9B59B6`.

Evidence: `.code_my_spec/qa/453/screenshots/s6_live_preview_before_save.png`

### Scenario 7 — Save custom subdomain (criterion 4154)

**Result: pass**

Filled subdomain `reports-andersonthefish` (colors `#E74C3C`/`#9B59B6` were pre-filled from phx-change state) and submitted. Flash "White-label settings saved" appeared. Input shows `reports-andersonthefish` after save. DNS panel shows the subdomain in instructions.

Evidence: `.code_my_spec/qa/453/screenshots/s7_save_subdomain.png`

### Scenario 8 — Subdomain persistence on page revisit (criterion 4154, 4157)

**Result: pass**

After saving `reports-andersonthefish`, navigated to `/accounts` then back to `/accounts/settings`. HTML inspection confirmed subdomain input pre-filled with `reports-andersonthefish` on fresh page load.

Evidence: `.code_my_spec/qa/453/screenshots/s8_subdomain_persists_on_revisit.png`

### Scenario 9 — DNS verification section after subdomain save (criterion 4158)

**Result: pass**

After subdomain save, verified:

- `[data-role="dns-verification"]` panel is present
- "DNS Verification Required" heading is visible
- Subdomain `reports-andersonthefish` appears in the CNAME instructions
- `[data-role="verify-dns"]` "Verify DNS" button is present
- "Pending verification" badge is shown (not "Active")

Evidence: `.code_my_spec/qa/453/screenshots/s9_dns_verification_section.png`

### Scenario 10 — Reset to Default button visibility (criterion 4156)

**Result: pass**

After saving settings, `[data-role="reset-white-label"]` "Reset to Default" button is visible.

Evidence: `.code_my_spec/qa/453/screenshots/s10_reset_button_visible.png`

### Scenario 11 — Reset to Default clears branding (criterion 4156)

**Result: pass**

Starting with saved config (subdomain `reports-andersonthefish`, colors `#E74C3C`/`#9B59B6`), clicked `[data-role="reset-white-label"]`. Flash "Branding reset to default" appeared. After reset:

- All four inputs have empty values
- `[data-role="reset-white-label"]` button is no longer visible
- `[data-role="dns-verification"]` panel is no longer visible

Evidence: `.code_my_spec/qa/453/screenshots/s11_after_reset_to_default.png`

### Scenario 12 — Settings stored at account level (criterion 4157)

**Result: pass**

Saved with `subdomain: storedagency`, `logo_url: https://cdn.agencytest.com/stored-logo.png`, `primary_color: #AA1122`, `secondary_color: #334455`. Navigated to `/accounts` then back to `/accounts/settings`. HTML inspection confirmed all four fields are pre-filled with the saved values after navigation.

Evidence: `.code_my_spec/qa/453/screenshots/s12_settings_persist_across_navigation.png`

### Scenario 13 — No Anderson Analytics branding (criterion 4159)

**Result: pass**

Checked `/accounts/settings` and `/dashboard` pages on the main domain (`localhost:4070`). No text "Anderson Analytics" appears on either page. The white-label branding is only applied when accessed via an agency subdomain — this is correct behavior.

Evidence: `.code_my_spec/qa/453/screenshots/s13_no_anderson_analytics_settings.png`, `.code_my_spec/qa/453/screenshots/s13_no_anderson_analytics_dashboard.png`

## Evidence

- `.code_my_spec/qa/453/screenshots/s1_white_label_section.png` — Settings page with white-label form; all required inputs present
- `.code_my_spec/qa/453/screenshots/s2_save_png_logo_url.png` — After saving PNG logo URL from nil state; flash visible, all four values pre-filled
- `.code_my_spec/qa/453/screenshots/s3_jpg_url_retained_after_phx_change.png` — HTML showing JPG URL retained in input after phx-change fired (bug fix confirmation)
- `.code_my_spec/qa/453/screenshots/s3_save_jpg_logo_url.png` — After saving JPG logo URL update to existing config; both logo_url and subdomain correctly saved
- `.code_my_spec/qa/453/screenshots/s4_save_svg_logo_url.png` — After saving SVG logo URL from nil state; SVG URL pre-filled
- `.code_my_spec/qa/453/screenshots/s5_save_color_scheme.png` — After saving color scheme (#3498DB / #2ECC71); both colors pre-filled
- `.code_my_spec/qa/453/screenshots/s6_live_preview_before_save.png` — Live preview panel showing #E74C3C and #9B59B6 before form submission
- `.code_my_spec/qa/453/screenshots/s7_save_subdomain.png` — After saving subdomain reports-andersonthefish; DNS panel visible
- `.code_my_spec/qa/453/screenshots/s8_subdomain_persists_on_revisit.png` — Subdomain pre-filled after navigating away and back
- `.code_my_spec/qa/453/screenshots/s9_dns_verification_section.png` — DNS verification panel with subdomain, Verify DNS button, Pending verification badge
- `.code_my_spec/qa/453/screenshots/s10_reset_button_visible.png` — Reset to Default button visible when config exists
- `.code_my_spec/qa/453/screenshots/s11_after_reset_to_default.png` — After reset: form empty, reset button gone, DNS panel gone, flash "Branding reset to default"
- `.code_my_spec/qa/453/screenshots/s12_settings_persist_across_navigation.png` — All four saved fields pre-filled after navigate away/back
- `.code_my_spec/qa/453/screenshots/s13_no_anderson_analytics_settings.png` — Settings page; no Anderson Analytics text
- `.code_my_spec/qa/453/screenshots/s13_no_anderson_analytics_dashboard.png` — Dashboard page; no Anderson Analytics text

## Issues

No issues found. The HIGH bug from the previous QA run (phx-change overwriting user edits when config exists) has been fixed. All 13 scenarios pass.
