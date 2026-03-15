# Wallaby — Browser-Based Integration Testing

## Sources
- Wallaby hex package: https://hex.pm/packages/wallaby
- Wallaby docs: https://hexdocs.pm/wallaby/Wallaby.html
- Wallaby GitHub: https://github.com/elixir-wallaby/wallaby
- Wallaby.Feature docs: https://hexdocs.pm/wallaby/Wallaby.Feature.html
- Wallaby.Browser docs: https://hexdocs.pm/wallaby/Wallaby.Browser.html
- Wallaby.Query docs: https://hexdocs.pm/wallaby/Wallaby.Query.html

---

## Overview

Wallaby is a concurrent browser testing library for Elixir. It drives a real browser (Chrome via ChromeDriver) and interacts with your application the way a user would — clicking buttons, filling forms, reading text. Tests run concurrently by default with automatic browser lifecycle management.

| Concept           | Detail                                           |
|-------------------|--------------------------------------------------|
| Library           | `wallaby` (hex: `wallaby`, latest: `~> 0.30`)   |
| Driver            | ChromeDriver (default), Selenium                 |
| Concurrency       | Concurrent by default, one browser per test      |
| Test macro        | `feature` (replaces `test`)                      |
| Foundation        | ExUnit with `async: true` support                |
| Ecto integration  | Built-in sandbox support via user_agent metadata |

---

## Setup

### 1. Add dependency

```elixir
# mix.exs
defp deps do
  [
    {:wallaby, "~> 0.30", only: :test, runtime: false}
  ]
end
```

### 2. Configure the driver

```elixir
# config/test.exs
config :wallaby,
  driver: Wallaby.Chrome,
  otp_app: :my_app,
  screenshot_on_failure: true

# Ensure endpoint is started for browser tests
config :my_app, MyAppWeb.Endpoint,
  server: true
```

### 3. Set up test helper

```elixir
# test/test_helper.exs
{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, MyAppWeb.Endpoint.url())
ExUnit.start()
```

### 4. Configure Ecto sandbox for concurrent tests

```elixir
# lib/my_app_web/endpoint.ex
# Add to the endpoint plug pipeline (ONLY in test):
if Application.compile_env(:my_app, :sql_sandbox) do
  plug Phoenix.Ecto.SQL.Sandbox
end

# config/test.exs
config :my_app, :sql_sandbox, true
```

### 5. Create a FeatureCase helper

```elixir
# test/support/feature_case.ex
defmodule MyAppWeb.FeatureCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query
      import MyAppWeb.FeatureHelpers  # optional project-specific helpers
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(MyApp.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(MyApp.Repo, pid)
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    {:ok, session: session}
  end
end
```

---

## LiveView Configuration

Wallaby tests LiveView apps through the real browser. LiveView's WebSocket connection needs access to the Ecto sandbox. This requires passing the sandbox metadata through the user_agent.

### Endpoint configuration

```elixir
# lib/my_app_web/endpoint.ex
socket "/live", Phoenix.LiveView.Socket,
  websocket: [connect_info: [:user_agent, session: @session_options]]
```

### Allow sandbox in LiveView mounts

Use an `on_mount` hook or add to each LiveView:

```elixir
# lib/my_app_web/live/sandbox_hook.ex
defmodule MyAppWeb.SandboxHook do
  def on_mount(:default, _params, _session, socket) do
    allow_ecto_sandbox(socket)
    {:cont, socket}
  end

  defp allow_ecto_sandbox(socket) do
    %{assigns: %{__changed__: _}} = socket

    if connected?(socket) do
      user_agent =
        Phoenix.LiveView.get_connect_info(socket, :user_agent) || ""

      Phoenix.Ecto.SQL.Sandbox.allow(user_agent, Ecto.Adapters.SQL.Sandbox)
    end
  end

  defp connected?(%{transport_pid: pid}) when is_pid(pid), do: true
  defp connected?(_), do: false
end

# In your router:
live_session :default, on_mount: [MyAppWeb.SandboxHook] do
  # routes...
end
```

---

## Core API — Wallaby.Browser

All browser interaction functions are in `Wallaby.Browser` and are automatically imported when using `Wallaby.Feature`.

### Navigation

```elixir
session
|> visit("/users/register")
|> visit("/things")
```

### Finding Elements with Queries

Wallaby uses `Wallaby.Query` to locate elements. Import `Wallaby.Query` for convenience.

#### Query Functions

| Function | Finds by | Element type |
|---|---|---|
| `css(selector, opts)` | CSS selector | Any |
| `xpath(selector, opts)` | XPath expression | Any |
| `button(selector, opts)` | id, name, value, alt, title | `<button>`, `<input type="submit/button/image/reset">` |
| `link(selector, opts)` | id, link text, title, image alt | `<a>` |
| `text_field(selector, opts)` | id, name, placeholder, label | `<input type="text/email/password/...">`, `<textarea>` |
| `fillable_field(selector, opts)` | Same as text_field | Same as text_field |
| `checkbox(selector, opts)` | id, name, label | `<input type="checkbox">` |
| `radio_button(selector, opts)` | id, name, label | `<input type="radio">` |
| `select(selector, opts)` | id, name, label | `<select>` |
| `option(text, opts)` | Option text | `<option>` |
| `file_field(selector, opts)` | id, name, label | `<input type="file">` |

#### Query Options

| Option | Type | Default | Description |
|---|---|---|---|
| `:count` | integer or `:any` | `1` | Expected number of matching elements |
| `:minimum` | integer | `nil` | Minimum required matches |
| `:maximum` | integer | `nil` | Maximum allowed matches |
| `:visible` | boolean | `true` | Only match visible elements |
| `:selected` | boolean or `:any` | `:any` | Filter by selected state |
| `:text` | string | `nil` | Text the element must contain |
| `:at` | integer or `:all` | `:all` | Position when multiple matches |

#### Examples

```elixir
import Wallaby.Query

# By CSS selector
css("#user-form")
css(".alert.alert-info")
css("[data-role='submit-button']")

# By text content
button("Save")
link("Sign In")

# By form field labels
text_field("Email")
fillable_field("Name")       # alias for text_field

# By select/checkbox/radio
select("Country")
checkbox("Remember me")

# By data attribute
css("[data-testid='user-card']")

# With text filter
css(".alert", text: "successfully")
css("h1", text: "Dashboard")

# Count assertions
css(".user-row", count: 3)
css(".error", count: 0)       # assert element does NOT exist

# Minimum count
css(".item", minimum: 1)

# Visibility
css("#modal", visible: true)
css("#hidden-field", visible: false)
```

### Finding Elements

```elixir
# Find a single element (raises if not found within max_wait_time)
session |> find(css("#login-button"))

# Find with callback (scopes operations to element, returns session for chaining)
session
|> find(css(".modal"), fn modal ->
  modal
  |> fill_in(text_field("Name"), with: "Alice")
  |> click(button("Save"))
end)

# Get all matching elements as list
elements = session |> all(css(".list-item"))
```

### Interacting with Elements

```elixir
session
|> visit("/things/new")
|> fill_in(text_field("Name"), with: "My Thing")
|> fill_in(text_field("Description"), with: "A great thing")
|> click(button("Save"))
```

### Form Interactions

```elixir
# Fill text fields
session |> fill_in(text_field("Email"), with: "user@example.com")
session |> fill_in(text_field("Password"), with: "SecurePass123!")

# Clear and fill
session |> clear(text_field("Name"))
session |> fill_in(text_field("Name"), with: "New Name")

# Select dropdowns
session |> click(option("United States"))

# Checkboxes
session |> set_value(checkbox("Remember me"), :selected)
session |> set_value(checkbox("Remember me"), :unselected)

# File uploads
session |> attach_file(file_field("Avatar"), path: "/path/to/image.jpg")

# Submit forms (click the submit button)
session |> click(button("Submit"))
session |> click(button("Save"))
```

### Keyboard Input

```elixir
# Send text and special keys
session |> send_keys(text_field("Search"), ["elixir wallaby", :enter])

# Modifier combos
session |> send_keys(css("#editor"), [:control, "a"])  # select all
```

Special key atoms: `:enter`, `:tab`, `:escape`, `:backspace`, `:delete`, `:space`,
`:shift`, `:control`, `:alt`, `:left_arrow`, `:right_arrow`, `:up_arrow`, `:down_arrow`,
`:home`, `:end`, `:pageup`, `:pagedown`

### Reading Content

```elixir
# Get text content of an element
session |> find(css(".alert")) |> Element.text()

# Get attribute value
session |> find(css("input#email")) |> Element.attr("value")

# Get page title
page_title(session)

# Get current path
current_path(session)
current_url(session)
```

### Assertions

```elixir
# Assert element exists (with text)
session |> assert_has(css(".alert", text: "Thing created successfully"))

# Assert element does NOT exist
session |> refute_has(css(".error"))

# Assert element with count
session |> assert_has(css(".user-row", count: 5))

# Assert current path
assert current_path(session) == "/things"

# Assert page title
assert page_title(session) =~ "Dashboard"

# Assert text content
assert session |> find(css("h1")) |> Element.text() == "Welcome"
```

### Waiting / Retry Behavior

Wallaby automatically retries queries for a configurable timeout (default: 3 seconds). This handles async rendering, LiveView updates, and animations without explicit waits.

```elixir
# These will automatically retry until the element appears or timeout:
session |> assert_has(css(".loaded-content", text: "Data loaded"))
session |> find(css("#dynamic-element"))
session |> click(button("Submit"))

# Configure global timeout
config :wallaby, js_timeout: 5_000

# Longer timeout for specific operations — NOT directly supported,
# but you can use Process.sleep as a last resort (avoid when possible)
```

### JavaScript Execution

```elixir
execute_script(session, "document.querySelector('#hidden').style.display = 'block'")
execute_script(session, "return document.title")
```

### Screenshots

```elixir
# Manual screenshot
take_screenshot(session)
take_screenshot(session, name: "after-login")

# Automatic on failure (configured globally)
config :wallaby, screenshot_on_failure: true

# Screenshot directory
config :wallaby, screenshot_dir: "tmp/wallaby_screenshots"
```

### Window Management

```elixir
resize_window(session, 1024, 768)
maximize_window(session)
window_size(session)  # returns {width, height}
```

---

## Wallaby.Feature Module

`use Wallaby.Feature` replaces `use ExUnit.Case` and provides:
- The `feature` macro (replaces `test`)
- Automatic session management via `@sessions` attribute
- Import of `Wallaby.Browser` functions

```elixir
defmodule MyAppWeb.Features.UserRegistrationTest do
  use MyAppWeb.FeatureCase

  feature "user can register", %{session: session} do
    session
    |> visit("/users/register")
    |> fill_in(text_field("Email"), with: "newuser@example.com")
    |> fill_in(text_field("Password"), with: "ValidPassword123!")
    |> click(button("Create account"))
    |> assert_has(css(".alert", text: "registered successfully"))
  end
end
```

### Multiple Sessions (Concurrent Users)

Test multi-user interactions by setting `@sessions`:

```elixir
defmodule MyAppWeb.Features.ChatTest do
  use MyAppWeb.FeatureCase

  @sessions 2

  feature "users can chat", %{sessions: [user1, user2]} do
    user1
    |> visit("/chat")
    |> fill_in(text_field("Message"), with: "Hello from user 1!")
    |> click(button("Send"))

    user2
    |> visit("/chat")
    |> assert_has(css(".message", text: "Hello from user 1!"))
    |> fill_in(text_field("Message"), with: "Hello back!")
    |> click(button("Send"))

    user1
    |> assert_has(css(".message", text: "Hello back!"))
  end
end
```

### Named Sessions with Custom Configuration

```elixir
@sessions [
  admin: [user_agent: "admin"],
  regular: [user_agent: "regular"]
]

feature "admin sees extra controls", %{sessions: %{admin: admin, regular: regular}} do
  admin
  |> visit("/dashboard")
  |> assert_has(css("#admin-panel"))

  regular
  |> visit("/dashboard")
  |> refute_has(css("#admin-panel"))
end
```

---

## ChromeDriver Configuration

### Headless mode (default, CI-friendly)

```elixir
# config/test.exs
config :wallaby,
  driver: Wallaby.Chrome,
  chromedriver: [
    headless: true
  ],
  hackney_options: [timeout: 10_000]
```

### Headed mode (debugging)

```elixir
config :wallaby,
  driver: Wallaby.Chrome,
  chromedriver: [
    headless: false
  ]
```

### Custom Chrome binary

```elixir
config :wallaby,
  driver: Wallaby.Chrome,
  chrome: "/usr/bin/google-chrome-stable",
  chromedriver: [
    path: "/usr/local/bin/chromedriver"
  ]
```

### Chrome capabilities

```elixir
config :wallaby,
  driver: Wallaby.Chrome,
  chrome: [
    headless: true,
    # Window size
    args: ["--window-size=1920,1080", "--disable-gpu", "--no-sandbox"]
  ]
```

---

## Common Patterns

### Authentication Helper

```elixir
defmodule MyAppWeb.FeatureHelpers do
  import Wallaby.Browser
  import Wallaby.Query

  def log_in(session, email, password) do
    session
    |> visit("/users/log_in")
    |> fill_in(text_field("Email"), with: email)
    |> fill_in(text_field("Password"), with: password)
    |> click(button("Log in"))
  end

  def register_user(session, attrs \\ %{}) do
    email = Map.get(attrs, :email, "user#{System.unique_integer()}@example.com")
    password = Map.get(attrs, :password, "ValidPassword123!")

    session
    |> visit("/users/register")
    |> fill_in(text_field("Email"), with: email)
    |> fill_in(text_field("Password"), with: password)
    |> click(button("Create account"))
  end
end
```

### CRUD Test Pattern

```elixir
defmodule MyAppWeb.Features.ThingManagementTest do
  use MyAppWeb.FeatureCase

  setup %{session: session} do
    # Register and log in via the UI (surface-layer only)
    session
    |> register_user()
    |> assert_has(css(".alert", text: "registered"))

    {:ok, session: session}
  end

  feature "create a new thing", %{session: session} do
    session
    |> visit("/things/new")
    |> fill_in(text_field("Name"), with: "My Thing")
    |> click(button("Save"))
    |> assert_has(css(".alert", text: "Thing created successfully"))
  end

  feature "see validation errors", %{session: session} do
    session
    |> visit("/things/new")
    |> fill_in(text_field("Name"), with: "")
    |> click(button("Save"))
    |> assert_has(css(".error", text: "can't be blank"))
  end

  feature "list existing things", %{session: session} do
    # Create via UI first
    session
    |> visit("/things/new")
    |> fill_in(text_field("Name"), with: "Listed Thing")
    |> click(button("Save"))
    |> visit("/things")
    |> assert_has(css("td", text: "Listed Thing"))
  end

  feature "delete a thing", %{session: session} do
    # Create first
    session
    |> visit("/things/new")
    |> fill_in(text_field("Name"), with: "To Delete")
    |> click(button("Save"))
    |> visit("/things")
    |> assert_has(css("td", text: "To Delete"))

    accept_confirm(session, fn session ->
      session |> click(link("Delete"))
    end)

    session |> refute_has(css("td", text: "To Delete"))
  end
end
```

### Handling JavaScript Dialogs

```elixir
# Accept a confirmation dialog
accept_confirm(session, fn session ->
  session |> click(button("Delete"))
end)

# Dismiss a confirmation dialog
dismiss_confirm(session, fn session ->
  session |> click(button("Delete"))
end)

# Accept an alert
accept_alert(session, fn session ->
  session |> click(button("Show Alert"))
end)

# Accept a prompt with input
accept_prompt(session, [with: "My Answer"], fn session ->
  session |> click(button("Show Prompt"))
end)
```

---

## Debugging

### Screenshots on failure

```elixir
# Enabled globally
config :wallaby, screenshot_on_failure: true

# Manual screenshot during development
take_screenshot(session, name: "debug-state")
```

### Headed mode for visual debugging

```elixir
# config/test.exs — temporarily switch to see the browser
config :wallaby,
  chromedriver: [headless: false]
```

### Page source

```elixir
page_source(session)  # returns the full HTML
```

---

## Best Practices

| Prefer                                           | Over                                    | Why                              |
|--------------------------------------------------|-----------------------------------------|----------------------------------|
| `assert_has(css(".alert", text: "..."))`          | `assert text =~ "..."`                  | Auto-retries, handles async      |
| `click(button("Save"))`                          | `click(css("button[type=submit]"))`     | More readable, less brittle      |
| `fill_in(text_field("Email"), with: ...)`        | `fill_in(css("#user_email"), with: ...)` | Labels > CSS IDs                 |
| `data-testid` attributes                         | Fragile CSS selectors                   | Survives UI refactors            |
| `refute_has(css(".error"))`                      | Manual absence checks                   | Auto-retries for async removal   |
| Surface-layer setup (register via UI)            | Direct fixture/context calls            | Tests real user flows            |
| `FeatureCase` with sandbox setup                 | Manual session/sandbox management       | DRY, consistent                  |
