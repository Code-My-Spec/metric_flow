# Vibium Browser Automation — MCP Server Reference

The Vibium MCP server (`mcp__vibium`) provides browser automation tools that the agent calls directly. No CLI binary, no daemon management — the MCP server handles the browser lifecycle.

## Setup

The Vibium MCP server must be configured in your Claude Code MCP settings. Once configured, all `mcp__vibium__browser_*` tools are available to the agent automatically.

To start a browser session, call `browser_launch`. The MCP server keeps the browser alive across tool calls within the same session.

## Core Workflow

Every browser automation follows this pattern:

1. **Launch**: `browser_launch` (once per session)
2. **Navigate**: `browser_navigate` with `url`
3. **Map**: `browser_map` (get element refs like `@e1`, `@e2`)
4. **Interact**: Use refs or CSS selectors — e.g. `browser_click` with `selector: "@e1"`
5. **Re-map**: After navigation or DOM changes, get fresh refs with `browser_map`

## CLI to MCP Tool Mapping

All tools are prefixed with `mcp__vibium__`. Parameter names are listed in parentheses.

| CLI Command | MCP Tool | Key Parameters |
|---|---|---|
| `vibium go <url>` | `browser_navigate` | `url` |
| `vibium map` | `browser_map` | `selector` (optional scope) |
| `vibium diff map` | `browser_diff_map` | |
| `vibium click` | `browser_click` | `selector` |
| `vibium dblclick` | `browser_dblclick` | `selector` |
| `vibium fill` | `browser_fill` | `selector`, `text` |
| `vibium type` | `browser_type` | `selector`, `text` |
| `vibium press` | `browser_press` | `key`, `selector` (optional) |
| `vibium keys` | `browser_keys` | `keys` |
| `vibium hover` | `browser_hover` | `selector` |
| `vibium focus` | `browser_focus` | `selector` |
| `vibium select` | `browser_select` | `selector`, `value` |
| `vibium check` | `browser_check` | `selector` |
| `vibium uncheck` | `browser_uncheck` | `selector` |
| `vibium scroll` | `browser_scroll` | `selector` (optional), direction params |
| `vibium scroll-into-view` | `browser_scroll_into_view` | `selector` |
| `vibium drag` | `browser_drag` | `source`, `target` |
| `vibium upload` | `browser_upload` | `selector`, `files` |
| `vibium text` | `browser_get_text` | `selector` (optional) |
| `vibium html` | `browser_get_html` | `selector` (optional), `outer` |
| `vibium eval` | `browser_evaluate` | `expression` |
| `vibium find` | `browser_find` | `selector`, `text`, `label`, `placeholder`, `testid`, `role`, `alt`, `title`, `xpath` |
| `vibium find-all` | `browser_find_all` | `selector`, `text`, `role`, etc. |
| `vibium count` | `browser_count` | `selector` |
| `vibium screenshot` | `browser_screenshot` | `filename`, `fullPage`, `annotate` |
| `vibium pdf` | `browser_pdf` | `filename` |
| `vibium a11y-tree` | `browser_a11y_tree` | |
| `vibium highlight` | `browser_highlight` | `selector` |
| `vibium value` | `browser_get_value` | `selector` |
| `vibium attr` | `browser_get_attribute` | `selector`, `attribute` |
| `vibium is-visible` | `browser_is_visible` | `selector` |
| `vibium is-enabled` | `browser_is_enabled` | `selector` |
| `vibium is-checked` | `browser_is_checked` | `selector` |
| `vibium url` | `browser_get_url` | |
| `vibium title` | `browser_get_title` | |
| `vibium wait` | `browser_wait` | `selector`, `state`, `timeout` |
| `vibium wait-for-url` | `browser_wait_for_url` | `pattern`, `timeout` |
| `vibium wait-for-text` | `browser_wait_for_text` | `text`, `timeout` |
| `vibium wait-for-load` | `browser_wait_for_load` | `timeout` |
| `vibium wait-for-fn` | `browser_wait_for_fn` | `expression`, `timeout` |
| `vibium sleep` | `browser_sleep` | `ms` |
| `vibium back` | `browser_back` | |
| `vibium forward` | `browser_forward` | |
| `vibium reload` | `browser_reload` | |
| `vibium tabs` | `browser_list_tabs` | |
| `vibium tab-new` | `browser_new_tab` | `url` (optional) |
| `vibium tab-switch` | `browser_switch_tab` | `index` or `url` |
| `vibium tab-close` | `browser_close_tab` | `index` (optional) |
| `vibium storage-state` | `browser_storage_state` | (returns JSON directly) |
| `vibium restore-storage` | `browser_restore_storage` | `path` |
| `vibium cookies` | `browser_get_cookies` | |
| `vibium cookies set` | `browser_set_cookie` | `name`, `value`, etc. |
| `vibium cookies clear` | `browser_delete_cookies` | |
| `vibium set-viewport` | `browser_set_viewport` | `width`, `height` |
| `vibium viewport` | `browser_get_viewport` | |
| `vibium window` | `browser_get_window` | |
| `vibium set-window` | `browser_set_window` | `width`, `height`, `x`, `y` |
| `vibium emulate-media` | `browser_emulate_media` | media feature params |
| `vibium set-geolocation` | `browser_set_geolocation` | `latitude`, `longitude` |
| `vibium set-content` | `browser_set_content` | `html` |
| `vibium frames` | `browser_frames` | |
| `vibium frame` | `browser_frame` | `name` or `url` |
| `vibium trace start` | `browser_trace_start` | |
| `vibium trace stop` | `browser_trace_stop` | |
| `vibium download set-dir` | `browser_download_set_dir` | `path` |
| `vibium dialog accept` | `browser_dialog_accept` | `text` (optional) |
| `vibium dialog dismiss` | `browser_dialog_dismiss` | |
| `vibium quit` | `browser_quit` | |
| `vibium daemon start` | `browser_launch` | `headless` |

## Key Differences from CLI

| Aspect | CLI | MCP Server |
|---|---|---|
| Browser lifecycle | Manual daemon start/stop, stale socket cleanup | `browser_launch` — MCP server manages everything |
| Command chaining | `&&` between shell commands | Sequential tool calls — no chaining needed |
| Output | Stdout text | Structured tool results returned to agent |
| Auth scripts | Shell scripts (`login.sh`, `logout.sh`) | Agent calls MCP tools directly in sequence |
| Refs (`@e1`) | Returned as text, used as CLI args | Returned in tool results, passed as `selector` params |
| `eval` vs `evaluate` | CLI command is `eval` | MCP tool is `browser_evaluate` |
| `storage-state -o file` | Writes to file | `browser_storage_state` returns JSON directly |
| `screenshot -o file` | `-o` flag | `filename` parameter |

## Ref Lifecycle

Refs (`@e1`, `@e2`) from `browser_map` are invalidated when the page changes. Always re-map after:
- Clicking links or buttons that navigate
- Form submissions
- Dynamic content loading (dropdowns, modals)

## Phoenix LiveView Patterns

### Login with phx.gen.auth

The login page has two forms — scroll the password form into view before interacting:

```
browser_navigate(url: "http://localhost:4000/users/log-in")
browser_scroll_into_view(selector: "#login_form_password")
browser_fill(selector: "#login_form_password_email", text: "qa@example.com")
browser_fill(selector: "#user_password", text: "hello world!")
browser_click(selector: "#login_form_password button[name='user[remember_me]']")
browser_wait(selector: "body", timeout: 5000)
```

### Re-authentication detection

Check if the email field is readonly (user has an expired session):

```
browser_evaluate(expression: "document.querySelector('#login_form_password_email')?.hasAttribute('readonly') ?? false")
```

If `true`, skip the email fill step.

### Logout (data-method="delete" links)

Phoenix logout links use `data-method="delete"` — click them normally:

```
browser_click(selector: "a[href='/users/log-out']")
```

### LiveView page transitions

After LiveView navigation, wait for the new content:

```
browser_click(selector: "a[href='/accounts']")
browser_wait(selector: "[data-phx-session]", state: "attached")
```

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| Click/fill hangs then fails | Element below viewport | `browser_scroll_into_view` first |
| Login submits but nothing happens | Targeting wrong form (`#login_form_magic`) | Use `#login_form_password` selectors |
| Password login returns "invalid" | User not confirmed | Confirm via magic link token in seeds |
| Stale refs after navigation | Refs invalidated on page change | Call `browser_map` again |
