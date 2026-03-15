# QA Tooling Patterns

Guide for writing QA test infrastructure for Phoenix LiveView apps. Covers Vibium MCP browser automation, seed data scripts, and smoke tests.

## Tool selection: Vibium MCP vs curl

**Use the right tool for the right layer.** Getting this wrong wastes time and creates fragile scripts.

| What you're testing | Tool | Auth mechanism | Example |
|---|---|---|---|
| UI pages, LiveViews, forms, navigation | **Vibium MCP** | Browser session (login via MCP tools, persist with `browser_storage_state`) | `browser_navigate` + `browser_map` |
| API endpoints (`/api/*`) | **curl** | `X-Api-Key` header, bearer token, or no auth | `curl -H "X-Api-Key: $KEY" /api/transactions/1` |
| Webhooks | **curl** | Webhook signature or no auth | `curl -X POST -d '...' /api/webhooks/card-swipe` |
| Smoke tests (route reachability) | **curl** | None (just check HTTP status codes) | `curl -s -o /dev/null -w '%{http_code}' /` |

### The golden rule

**Never use curl for session-authenticated routes.** Phoenix session auth requires signed cookies, CSRF tokens, and form POSTs — scraping HTML for tokens is fragile and wrong. If the route is behind `:browser` pipeline + `:require_authenticated_user`, use Vibium MCP.

**Never use Vibium MCP for API endpoints.** API routes don't render HTML — there's nothing to click or screenshot. Use curl with the appropriate header.

### How Phoenix apps split auth

Most Phoenix apps have two pipelines in the router:

- **`:browser`** — session-based auth, CSRF protection, HTML responses. All LiveViews and page controllers live here. **-> Vibium MCP**
- **`:api`** — stateless auth (API keys, bearer tokens, webhook signatures), JSON responses. **-> curl**

Look at the router to determine which pipeline a route uses. That tells you which tool to use.

### `authenticated_curl.sh`

This script wraps curl with the account's API key. It's for API endpoints only — not for session-authenticated pages. If you need to test a LiveView page, use Vibium MCP tools.

## Seed data scripts (.exs)

Seed scripts go in `priv/repo/` and run via `mix run priv/repo/qa_seeds.exs`. Each script boots the BEAM once and runs all seed logic in-process.

### Why `.exs`, not bash

A bash script that calls `mix run -e '...'` per entity boots the entire Elixir application from scratch each time — compiling, connecting to the database, starting supervision trees. For 9 entities, that's 9 full boots. A single `.exs` script does it in one.

### Reference script: `priv/repo/qa_seeds.exs`

```elixir
# priv/repo/qa_seeds.exs
#
# Creates a complete QA test dataset.
# Idempotent — safe to run multiple times.
#
# Usage: mix run priv/repo/qa_seeds.exs

alias MyApp.{Accounts, Repo}
alias MyApp.Accounts.User

# --- Helper ---
defmodule QaSeed do
  def find_or_create(queryable, unique_field, unique_value, create_fn) do
    import Ecto.Query
    case Repo.one(from r in queryable, where: field(r, ^unique_field) == ^unique_value) do
      nil ->
        {:ok, record} = create_fn.()
        IO.puts("  Created: #{inspect(unique_value)}")
        record
      existing ->
        IO.puts("  Exists: #{inspect(unique_value)}")
        existing
    end
  end
end

# --- 1. User ---
IO.puts("\n--- User ---")
user = case Accounts.get_user_by_email("qa@example.com") do
  nil ->
    {:ok, user} = Accounts.register_user(%{email: "qa@example.com"})
    {:ok, {user, _}} = Accounts.update_user_password(user, %{password: "hello world!"})
    IO.puts("  Created: qa@example.com")
    user
  user ->
    IO.puts("  Exists: qa@example.com")
    user
end

scope = MyApp.Users.Scope.for_user(user)

# --- 2. More entities using context functions ---
IO.puts("\n--- Account ---")
account = QaSeed.find_or_create(MyApp.Accounts.Account, :name, "QA Account", fn ->
  Accounts.create_account(scope, %{name: "QA Account"})
end)

# ... more entities, each using context functions with scope

# --- Summary ---
IO.puts("""

==========================================
 QA Seed Data — Credentials
==========================================

Email:    qa@example.com
Password: hello world!
URL:      http://localhost:4000/users/log-in
""")
```

### Patterns

- **Idempotency**: check for existing records before inserting. Use context `get_by` functions or Ecto queries.
- **Use context functions**: call `Accounts.create_user(scope, attrs)` not `Repo.insert(%User{...})`. This ensures validations, associations, and side effects run.
- **Build Scope**: after creating the user, build a `Scope` to pass to all subsequent context calls.
- **Print credentials**: always print login info, URLs, and entity IDs at the end.
- **Multiple scripts**: split into separate files for different scenarios (base entities vs. specific test flows). Each is independently runnable.

## Smoke test scripts

For hitting every route and checking for 500s:

```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${APP_URL:-http://localhost:4000}"
FAIL=0

smoke() {
  local path="$1"
  local expected="${2:-200}"

  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL$path")

  if [ "$HTTP_CODE" = "$expected" ]; then
    echo "  PASS GET $path -> $HTTP_CODE"
  else
    echo "  FAIL GET $path -> $HTTP_CODE (expected $expected)"
    FAIL=1
  fi
}

# Public routes
smoke "/"
smoke "/users/log-in"
smoke "/users/register"

# Authenticated routes should redirect to login
smoke "/accounts" 302

exit $FAIL
```

### Tips

- Accept 302 as valid for auth-protected routes when not logged in
- Check for 500s specifically — a 404 or 302 might be expected
- Use `mix phx.routes` output to build the route list
- For authenticated route testing, use Vibium MCP with `browser_restore_storage`

## Phoenix LiveView Login Patterns

Phoenix apps generated with `phx.gen.auth` have specific login patterns that require careful handling. These patterns apply to all Vibium MCP-based QA automation.

### Login page structure

The `/users/log-in` page renders **two separate forms** side by side:
- `#login_form_magic` — email-only form that sends a magic link
- `#login_form_password` — email + password form that submits via `POST /users/log-in`

The password form is often **below the viewport fold** because it comes after the magic link form. You must scroll it into view before interacting, or interaction tools will timeout waiting for the element to be actionable.

### Re-authentication mode

When a user has an existing session (e.g., session expired but cookie remains), Phoenix renders the login page in re-auth mode where the email field has a `readonly` attribute. Detect this and skip the email field:

```
browser_evaluate(expression: "document.querySelector('#login_form_password_email')?.hasAttribute('readonly') ?? false")
```

If the result is `true`, skip the email fill step.

### Reference login sequence (MCP tools)

```
# 1. Navigate to login page
browser_navigate(url: "http://localhost:4000/users/log-in")

# 2. CRITICAL: scroll password form into view — it's below the magic link form
browser_scroll_into_view(selector: "#login_form_password")

# 3. Check for re-auth mode (readonly email field)
browser_evaluate(expression: "document.querySelector('#login_form_password_email')?.hasAttribute('readonly') ?? false")
# If false, fill email:
browser_fill(selector: "#login_form_password_email", text: "qa@example.com")

# 4. Fill password
browser_fill(selector: "#user_password", text: "hello world!")

# 5. Click "Log in and stay logged in"
browser_click(selector: "#login_form_password button[name='user[remember_me]']")

# 6. Wait for page to load after redirect
browser_wait(selector: "body", timeout: 5000)
```

### Reference logout sequence (MCP tools)

Phoenix logout uses a `<a href="/users/log-out" data-method="delete">` link. Phoenix JS intercepts the click and issues a DELETE request. Just click the link:

```
browser_navigate(url: "http://localhost:4000/")
browser_click(selector: "a[href='/users/log-out']")
```

### User switching

To test multi-user scenarios, log out first then log in as a different user using the login sequence above with different credentials.

### Seed script patterns for confirmed users

`phx.gen.auth` requires email confirmation before password login works. Seeds must confirm users programmatically:

```elixir
# Create user
{:ok, user} = Users.register_user(%{email: email, password: password, account_name: name})

# Confirm via magic link token (bypasses email)
{token, user_token} = UserToken.build_email_token(user, "login")
Repo.insert!(user_token)
{:ok, {confirmed_user, _}} = Users.login_user_by_magic_link(token)

# Set password after confirmation (magic link clears tokens)
{:ok, {final_user, _}} = Users.update_user_password(confirmed_user, %{password: password})
```

Always create at least two users (owner + member) for multi-user test scenarios. Password minimum is 12 characters — `"hello world!"` is exactly 12.

### Common pitfalls

| Problem | Cause | Fix |
|---------|-------|-----|
| Fill/click hangs then times out | Element below viewport, fails actionability check | `browser_scroll_into_view` first |
| Login form submits but nothing happens | Targeting wrong form (`#login_form_magic` instead of `#login_form_password`) | Use `#login_form_password` selectors |
| Password login returns "invalid email or password" | User not confirmed | Confirm via magic link token in seeds |
| Stale `@e` refs after navigation | Refs are invalidated on page change | Call `browser_map` again |

## Browser-based QA with Vibium MCP

Vibium is a browser automation tool by Jason Huggins (creator of Selenium). It drives a real Chrome instance via WebDriver BiDi. The Vibium MCP server exposes this as a set of MCP tools that the agent calls directly — no CLI binary, no daemon management, no shell scripts.

**Setup:** Configure the Vibium MCP server in your Claude Code MCP settings. All `mcp__vibium__browser_*` tools become available automatically.

### Core workflow

Every browser automation follows this pattern:

1. **Launch**: `browser_launch` (once per session, if not already running)
2. **Navigate**: `browser_navigate(url: "http://localhost:4000")`
3. **Map**: `browser_map` (get element refs like `@e1`, `@e2`)
4. **Interact**: Use refs to click, fill, select — e.g. `browser_click(selector: "@e1")`
5. **Re-map**: After navigation or DOM changes, get fresh refs with `browser_map`

### QA workflow: authenticate first, then test

**Step 1: Log in once at the start of the QA session**
```
browser_launch(headless: true)
browser_navigate(url: "http://localhost:4000/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait_for_url(pattern: "/dashboard")
```

`phx.gen.auth` generates predictable form IDs: `login_form_password` for password login, `login_form_magic` for passwordless/magic-link login, `registration_form` for registration.

**Step 2: Browse freely**
```
# Read page content as text
browser_navigate(url: "http://localhost:4000/dashboard")
browser_get_text()

# Take a screenshot for evidence
browser_navigate(url: "http://localhost:4000/settings")
browser_screenshot(filename: "settings.png")

# Get raw HTML when you need to inspect DOM structure
browser_navigate(url: "http://localhost:4000/items")
browser_get_html()
```

### Verifying page content

```
# Read all page text
browser_get_text()

# Read text within a specific element
browser_get_text(selector: "h1")
browser_get_text(selector: ".flash-message")

# Count elements
browser_count(selector: ".item")

# Check element state
browser_is_visible(selector: ".modal")
browser_is_enabled(selector: "button[type=submit]")
browser_get_value(selector: "input[name=email]")
browser_get_attribute(selector: "a", attribute: "href")

# Programmatic checks via JS
browser_evaluate(expression: "document.querySelector('h1')?.textContent")
browser_evaluate(expression: "document.querySelectorAll('.item').length")
```

### Interacting with LiveView pages

LiveView pages work like any other page with Vibium MCP. After interactions that trigger server-side changes, use explicit waits:

```
# Click a phx-click button
browser_click(selector: "button[phx-click='delete']")
browser_wait_for_text(text: "deleted")

# Submit a LiveView form
browser_fill(selector: "#item_name", text: "Test Item")
browser_click(selector: "button[type=submit]")
browser_wait_for_url(pattern: "/items")

# Trigger a phx-change event (e.g., select dropdown)
browser_select(selector: "select[name='filter']", value: "active")

# Wait for LiveView to reconnect after navigation
browser_wait(selector: "[data-phx-session]", state: "attached")
```

### Filling and submitting forms

Use `browser_map` to discover form fields, then `browser_fill` to set values:

```
# Create a new item via form
browser_navigate(url: "http://localhost:4000/items/new")
browser_map(selector: "form")
# Map output shows: @e1 [input] name="item[name]", @e2 [textarea] name="item[description]", @e3 [button] "Save"
browser_fill(selector: "@e1", text: "Test Item")
browser_fill(selector: "@e2", text: "Created by QA")
browser_click(selector: "@e3")
browser_wait_for_url(pattern: "/items")
```

Use `browser_fill` to replace a field's value (clears first), `browser_type` to append to existing value.

### Semantic element discovery

Find elements without CSS selectors:
```
browser_find(text: "Sign In")           # by visible text
browser_find(label: "Email")            # by form label
browser_find(placeholder: "Search...")  # by placeholder
browser_find(testid: "submit-btn")      # by data-testid
browser_find(role: "button")            # by ARIA role
browser_find(alt: "Logo")              # by alt attribute
browser_click(selector: "@e1")          # click whatever was found
```

### Screenshots as evidence

Always take screenshots for QA evidence, especially for visual checks:
```
browser_screenshot(filename: "qa_dashboard.png")
browser_screenshot(filename: "annotated.png", annotate: true)
browser_screenshot(filename: "full.png", fullPage: true)
```

### Advanced interactions

```
# File upload
browser_upload(selector: "input[type=file]", files: ["./document.pdf"])

# Multi-tab workflows (OAuth redirects, popups)
browser_new_tab(url: "http://external-provider.com/authorize")
browser_click(selector: "#authorize-button")
browser_switch_tab(index: 0)

# Drag-and-drop
browser_drag(source: ".draggable", target: ".drop-target")

# Keyboard shortcuts
browser_keys(keys: "Control+a")
browser_press(key: "Enter", selector: "#search-input")

# Hover interactions
browser_hover(selector: ".menu-trigger")

# Viewport testing
browser_set_viewport(width: 375, height: 812)  # iPhone viewport
browser_screenshot(filename: "mobile.png")
```

### Key tools by category

| Category | MCP Tools |
|----------|-----------|
| Navigate | `browser_navigate`, `browser_back`, `browser_forward`, `browser_reload`, `browser_get_url`, `browser_get_title` |
| Discover | `browser_map`, `browser_diff_map`, `browser_find`, `browser_find_all`, `browser_count` |
| Read | `browser_get_text`, `browser_get_html`, `browser_screenshot`, `browser_a11y_tree`, `browser_evaluate` |
| Interact | `browser_click`, `browser_dblclick`, `browser_fill`, `browser_type`, `browser_press`, `browser_hover`, `browser_scroll`, `browser_keys`, `browser_select`, `browser_check`, `browser_uncheck` |
| Forms | `browser_fill` (clear+type), `browser_type` (append), `browser_select`, `browser_upload`, `browser_get_value` |
| State | `browser_is_visible`, `browser_is_enabled`, `browser_is_checked`, `browser_get_attribute`, `browser_get_value` |
| Wait | `browser_wait`, `browser_wait_for_url`, `browser_wait_for_text`, `browser_wait_for_load`, `browser_wait_for_fn` |
| Tabs | `browser_list_tabs`, `browser_new_tab`, `browser_switch_tab`, `browser_close_tab` |
| Auth | `browser_storage_state`, `browser_restore_storage`, `browser_get_cookies`, `browser_set_cookie`, `browser_delete_cookies` |
| Capture | `browser_screenshot` (`fullPage`, `annotate`), `browser_pdf` |
| Session | `browser_launch`, `browser_quit` |

### Troubleshooting

- **Stale refs?** Always re-map after navigation or DOM changes — refs are invalidated on page change
- **Element not actionable?** All interaction tools auto-wait, but use explicit `browser_wait` for dynamically loaded content
- **Need full tool reference?** See `priv/knowledge/qa-tooling/vibium_reference.md`

## Example Scripts

### Browser session auth (Vibium MCP — for UI/LiveView routes)

The agent calls MCP tools directly for login/logout/QA setup. See the "Reference login sequence" and "Reference logout sequence" sections above for the tool call patterns.

For QA session setup:
1. Run seeds via bash: `mix run priv/repo/qa_seeds.exs`
2. Launch browser: `browser_launch(headless: true)`
3. Log in using the login sequence above
4. Browse and test

### API auth (curl — for `/api/*` routes)
- `authenticated_curl_example.sh` — Wraps curl with the account's API key header. Looks up the key from the database or falls back to a known seed value. Use as a template for `authenticated_curl.sh`.

Copy and adapt the curl script for your project. The Vibium MCP tool call patterns above demonstrate browser lifecycle, seed runner integration, and `phx.gen.auth` login patterns.
