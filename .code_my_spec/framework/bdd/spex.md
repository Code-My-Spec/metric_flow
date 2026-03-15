# BDD Specifications with Spex + LiveViewTest

## Sources
- SexySpex hex package: https://hex.pm/packages/sexy_spex
- SexySpex docs: https://hexdocs.pm/sexy_spex
- Phoenix.LiveViewTest: https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html

---

## Overview

Spex is a BDD framework for Elixir built on ExUnit. It provides a Given-When-Then DSL for writing executable specifications that serve as both acceptance tests and living documentation. Spex files run exclusively via `mix spex`, never `mix test`.

BDD specs use **Phoenix.LiveViewTest** for LiveView interactions — mounting views, rendering forms, clicking elements, and asserting on HTML output. This tests at the surface layer without needing a real browser.

> For the full LiveViewTest API reference, see `../liveview/testing.md`.

| Concept             | Detail                                          |
|---------------------|-------------------------------------------------|
| Framework           | `SexySpex` (hex: `sexy_spex`)                   |
| LiveView testing    | `Phoenix.LiveViewTest`                          |
| Controller testing  | `Phoenix.ConnTest`                              |
| Foundation          | ExUnit with `async: false`                      |
| DSL macros          | `spex`, `scenario`, `given_`, `when_`, `then_`, `and_` |
| File pattern        | `test/spex/**/*_spex.exs`                       |
| Run command         | `mix spex`                                      |
| Boundary module     | `AppSpex` in `test/spex/app_spex.ex`            |
| Shared givens       | `AppSpex.SharedGivens` in `test/support/shared_givens.ex` |

---

## Project Structure

```
test/spex/
├── my_app_spex.ex              # Boundary definition (deps: [MyAppWeb, MyAppTest])
└── {story_id}_{story_slug}/    # One directory per story
    ├── criterion_{id}_{slug}_spex.exs
    └── criterion_{id}_{slug}_spex.exs
```

### Boundary Definition

Every project needs a boundary module that restricts spex files to the web layer:

```elixir
defmodule MyAppSpex do
  @moduledoc """
  Boundary definition for BDD specifications.

  Enforces surface-layer testing — spex files can only depend on the
  Web layer and test support, not context modules directly.
  """

  use Boundary, deps: [MyAppWeb, MyAppTest], exports: []
end
```

> For the full boundary library reference and application-wide hierarchy, see `../boundary.md`.

---

## Spex DSL Reference

### Module Setup

```elixir
defmodule MyAppSpex.UserRegistrationSpex do
  use SexySpex                    # ExUnit.Case (async: false) + DSL import
  use MyAppWeb.ConnCase           # Provides conn, endpoint, routing helpers
  import Phoenix.LiveViewTest     # live/2, form/3, element/3, render_click/1, etc.

  import_givens MyAppSpex.SharedGivens  # Shared step definitions
end
```

`use SexySpex` expands to:

```elixir
use ExUnit.Case, async: false
import SexySpex.DSL
require Logger
```

`use MyAppWeb.ConnCase` provides the `conn` in the test context and sets up the endpoint. `import Phoenix.LiveViewTest` brings in `live/2`, `form/3`, `element/3`, `render_click/1`, `render_submit/1`, `has_element?/2`, etc.

All standard ExUnit features remain available: `setup_all`, `setup`, `on_exit`, `assert`, `refute`, `assert_raise`.

### Macros

| Macro           | Purpose                  | Args                              |
|-----------------|--------------------------|-----------------------------------|
| `spex/2`        | Define a specification   | `name`, `do: block`               |
| `spex/3`        | Spec with options        | `name`, `opts`, `do: block`       |
| `scenario/2`    | Group steps (no context) | `name`, `do: block`               |
| `scenario/3`    | Group steps with context | `name`, `context`, `do: block`    |
| `given_/2`      | Precondition (no ctx)    | `description`, `do: block`        |
| `given_/3`      | Precondition with ctx    | `description`, `context`, `do: block` |
| `when_/2`       | Action (no context)      | `description`, `do: block`        |
| `when_/3`       | Action with context      | `description`, `context`, `do: block` |
| `then_/2`       | Assertion (no context)   | `description`, `do: block`        |
| `then_/3`       | Assertion with context   | `description`, `context`, `do: block` |
| `and_/2`        | Additional step (no ctx) | `description`, `do: block`        |
| `and_/3`        | Additional step with ctx | `description`, `context`, `do: block` |

### Spex Options

```elixir
spex "user registration",
  description: "Validates the full registration flow",
  tags: [:authentication, :registration] do
  # scenarios here
end
```

| Option          | Type              | Purpose                         |
|-----------------|-------------------|---------------------------------|
| `:description`  | `String.t()`      | Human-readable summary          |
| `:tags`         | `[atom()]`        | Categorization (printed, not filterable) |

---

## Context Flow

Context is an explicit map that threads state between steps. Each step that takes a `context` parameter receives the current context and must return `:ok` or `{:ok, updated_context}`.

### How Context Flows

1. ExUnit's `setup` or `setup_all` provides the initial context (e.g., `%{conn: conn}`)
2. `scenario "name", context do` initializes the scenario context from ExUnit
3. Each step receives context, returns `:ok` (keep unchanged) or `{:ok, new_context}` (update)
4. The next step receives the updated context

### Context Rules

| Rule                                    | Example                                            |
|-----------------------------------------|----------------------------------------------------|
| Return `{:ok, context}` to update       | `{:ok, Map.put(context, :view, view)}`             |
| Return `:ok` to keep context unchanged  | `:ok` (common in `then_` steps)                    |
| Use `_context` when unused              | `given_ "desc", _context do`                       |
| Omit context when not needed            | `then_ "desc" do assert true end`                  |

**Important:** Returning a bare map will raise `ArgumentError`. Always wrap in `{:ok, map}`.

### Pattern

```elixir
scenario "user registers successfully", context do
  given_ "the registration page is loaded", context do
    {:ok, view, _html} = live(context.conn, "/users/register")
    {:ok, Map.put(context, :view, view)}
  end

  when_ "user submits valid credentials", context do
    context.view
    |> form("#registration-form", user: %{
      email: "test@example.com",
      password: "SecurePass123!"
    })
    |> render_submit()

    :ok
  end

  then_ "user sees welcome message", context do
    assert render(context.view) =~ "Welcome"
    :ok
  end
end
```

---

## Testing Patterns by Component Type

### LiveView Specs (Surface Layer)

Test what users **see and do** through LiveViewTest. Do not call context functions directly.

```elixir
defmodule MyAppSpex.UserRegistrationSpex do
  use SexySpex
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MyAppSpex.SharedGivens

  spex "User registration",
    description: "Users can register through the registration form",
    tags: [:authentication] do

    scenario "user registers with valid data", context do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user fills in and submits the form", context do
        context.view
        |> form("#registration-form", user: %{
          email: "newuser@example.com",
          password: "ValidPassword123!"
        })
        |> render_submit()

        :ok
      end

      then_ "user sees success confirmation", context do
        assert render(context.view) =~ "registered successfully"
        :ok
      end
    end

    scenario "user sees validation errors for invalid input", context do
      given_ "the registration page is loaded", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user submits invalid data", context do
        context.view
        |> form("#registration-form", user: %{
          email: "not-an-email",
          password: "short"
        })
        |> render_submit()

        :ok
      end

      then_ "user sees error messages", context do
        html = render(context.view)
        assert html =~ "must have the @ sign"
        assert html =~ "should be at least"
        :ok
      end
    end
  end
end
```

#### LiveViewTest Testing Helpers

| Action                     | Code                                                      |
|----------------------------|------------------------------------------------------------|
| Mount LiveView             | `{:ok, view, html} = live(conn, "/path")`                 |
| Submit form                | `view \|> form("#form", data: %{}) \|> render_submit()`   |
| Click element              | `view \|> element("button", "Text") \|> render_click()`   |
| Change form                | `view \|> form("#form", data: %{}) \|> render_change()`   |
| Assert HTML content        | `assert render(view) =~ "expected text"`                  |
| Assert element exists      | `assert has_element?(view, "#element-id")`                |
| Assert element gone        | `refute has_element?(view, "#element-id")`                |
| Assert patch navigation    | `assert_patch view, "/target"`                            |
| Assert redirect            | `assert_redirect view, "/target"`                         |
| Get page title             | `assert page_title(view) =~ "My Title"`                  |

### Controller Specs (Surface Layer)

Controller specs that test JSON APIs or form POST endpoints use `Phoenix.ConnTest` directly:

```elixir
defmodule MyAppSpex.ResourceApiSpex do
  use SexySpex
  use MyAppWeb.ConnCase

  import_givens MyAppSpex.SharedGivens

  spex "Resource API" do
    scenario "create resource with valid data", context do
      when_ "client submits valid data", context do
        conn = post(context.conn, "/api/resources", %{
          resource: %{name: "Test Resource"}
        })
        {:ok, Map.put(context, :response_conn, conn)}
      end

      then_ "API returns created resource", context do
        assert %{"id" => _, "name" => "Test Resource"} =
          json_response(context.response_conn, 201)
        :ok
      end
    end
  end
end
```

---

## Shared Givens

Shared givens extract duplicated setup code into reusable named steps. They live in `test/support/shared_givens.ex`.

### Definition

```elixir
defmodule MyAppSpex.SharedGivens do
  @moduledoc """
  Shared given steps for BDD specifications.

  Import in spec files with:
      import_givens MyAppSpex.SharedGivens
  """

  use SexySpex.Givens

  # Each shared given sets up state through the UI, not fixtures
  # given_ :user_registered, context do
  #   conn = Phoenix.ConnTest.build_conn()
  #   {:ok, view, _html} = Phoenix.LiveViewTest.live(conn, "/users/register")
  #
  #   view
  #   |> Phoenix.LiveViewTest.form("#registration-form", user: %{
  #     email: "test#{System.unique_integer()}@example.com",
  #     password: "ValidPassword123!"
  #   })
  #   |> Phoenix.LiveViewTest.render_submit()
  #
  #   {:ok, %{}}
  # end
end
```

### Usage in Specs

```elixir
defmodule MyAppSpex.DashboardSpex do
  use SexySpex
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MyAppSpex.SharedGivens

  spex "Dashboard" do
    scenario "authenticated user sees dashboard", context do
      given_ :user_registered          # atom syntax — references shared given
      given_ "user navigates to dashboard", context do
        {:ok, view, _html} = live(context.conn, "/dashboard")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "dashboard content is visible", context do
        assert render(context.view) =~ "Welcome"
        :ok
      end
    end
  end
end
```

### When to Use Shared Givens

| Use shared givens for                          | Use inline givens for                     |
|------------------------------------------------|-------------------------------------------|
| Setup duplicated across multiple specs         | One-off, scenario-specific setup          |
| Generic state (user registered, logged in)     | Criterion-specific test data              |
| Commonly needed preconditions                  | Complex context that varies per scenario  |

Shared givens must set up state through the UI (LiveViewTest/ConnTest), not by calling context functions or fixtures directly.

---

## Surface Layer Testing Principles

BDD specs test **user-facing behavior**, not internal implementation. This enforces a strict boundary: specs interact with the application the same way a real user would — through the web layer.

| Principle                              | Correct                                             | Incorrect                               |
|----------------------------------------|-----------------------------------------------------|-----------------------------------------|
| Test what users see                    | `assert render(view) =~ "Welcome"`                  | `assert Users.get!(id).active?`         |
| Set up state through UI               | `form("#reg-form", user: attrs) \|> render_submit()` | `Users.create_user(scope, attrs)`       |
| Assert on user feedback                | `assert render(view) =~ "saved"`                    | `assert {:ok, _} = Things.create(...)` |
| Use web layer dependencies only        | `use MyAppWeb.ConnCase`                              | `alias MyApp.Users`                     |

> The `boundary` library enforces this surface-layer constraint at compile time. See `../boundary.md`.

### Path Conventions

Use plain string paths with LiveViewTest:

```elixir
# Correct
{:ok, view, _html} = live(conn, "/users/register")

# Avoid — ~p sigil requires importing Phoenix.VerifiedRoutes
{:ok, view, _html} = live(conn, ~p"/users/register")
```

---

## Running Spex

```bash
# Run all spex files (default pattern: test/spex/**/*_spex.exs)
mix spex

# Run a specific file
mix spex test/spex/123_user_registration/criterion_456_valid_email_spex.exs

# Run with a custom pattern
mix spex --pattern "**/integration_*_spex.exs"

# Verbose output (ExUnit trace mode)
mix spex --verbose

# Manual mode — pause at each step, IEx debugging
mix spex --manual

# Custom timeout (default: 60s)
mix spex --timeout 120000
```

| Flag             | Short | Purpose                                    |
|------------------|-------|--------------------------------------------|
| `--pattern`      |       | Glob pattern for spex files                |
| `--verbose`      | `-v`  | Trace mode with detailed output            |
| `--manual`       | `-m`  | Interactive step-by-step execution         |
| `--timeout`      |       | Test timeout in milliseconds               |
| `--help`         | `-h`  | Show usage information                     |

### Manual Mode

Manual mode pauses before each step and offers:
- **[ENTER]** — continue executing the step
- **[iex]** — drop into a debug shell (evaluate arbitrary Elixir, type `exit` to return)
- **[q]** — quit test execution

---

## ExUnit Integration

Since Spex is built on ExUnit, all standard callbacks and assertions are available.

### Setup Callbacks

```elixir
defmodule MyAppSpex.FeatureSpex do
  use SexySpex
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  # ConnCase setup already provides :conn in context
  # Add additional setup if needed:
  setup context do
    # additional setup here
    {:ok, context}
  end
end
```

### Assertions

All ExUnit assertions work in any step, alongside LiveViewTest assertions:

```elixir
given_ "the page is loaded", context do
  {:ok, view, _html} = live(context.conn, "/things/new")
  {:ok, Map.put(context, :view, view)}
end

then_ "page has expected content", context do
  # LiveViewTest assertions
  assert has_element?(context.view, "h1", "New Thing")
  assert has_element?(context.view, "#thing-form")

  # Standard ExUnit assertions on rendered HTML
  assert render(context.view) =~ "New Thing"
  :ok
end
```

### Failure Behavior

When an assertion fails in any step:
1. The step raises an `ExUnit.AssertionError`
2. The scenario catches it and reports via `SexySpex.Reporter.scenario_failed/2`
3. The spex catches it and reports via `SexySpex.Reporter.spex_failed/2`
4. The error re-raises with full stacktrace
5. ExUnit marks the test as failed

---

## Output Format

Spex produces structured output with visual markers:

```
🎯 Running Spex: User registration
==================================================
   Validates the full registration flow
   Tags: #authentication #registration

  📋 Scenario: user registers with valid data
    Given: the registration page is loaded
    When: user fills in and submits the form
    Then: user sees success confirmation
  ✅ Scenario passed: user registers with valid data

  📋 Scenario: user sees validation errors for invalid input
    Given: the registration page is loaded
    When: user submits invalid data
    Then: user sees error messages
  ✅ Scenario passed: user sees validation errors for invalid input

✅ Spex completed: User registration
```

---

## Complete Example: CRUD LiveView Spec

```elixir
defmodule MyAppSpex.ThingManagementSpex do
  use SexySpex
  use MyAppWeb.ConnCase
  import Phoenix.LiveViewTest

  import_givens MyAppSpex.SharedGivens

  spex "Thing management",
    description: "Users can create, view, edit, and delete things",
    tags: [:things, :crud] do

    scenario "user creates a new thing", context do
      given_ "user navigates to the new thing page", context do
        {:ok, view, _html} = live(context.conn, "/things/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user submits a valid thing", context do
        context.view
        |> form("#thing-form", thing: %{name: "My Thing"})
        |> render_submit()

        :ok
      end

      then_ "user sees the thing was created", context do
        assert render(context.view) =~ "Thing created successfully"
        :ok
      end
    end

    scenario "user sees validation errors", context do
      given_ "user navigates to the new thing page", context do
        {:ok, view, _html} = live(context.conn, "/things/new")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user submits without a name", context do
        context.view
        |> form("#thing-form", thing: %{name: ""})
        |> render_submit()

        :ok
      end

      then_ "user sees a validation error", context do
        assert render(context.view) =~ "can't be blank"
        :ok
      end
    end

    scenario "user lists existing things", context do
      given_ "user navigates to the things index", context do
        {:ok, view, _html} = live(context.conn, "/things")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "user sees the listing page", context do
        assert render(context.view) =~ "Listing Things"
        :ok
      end
    end

    scenario "user deletes a thing", context do
      given_ "a thing exists and user is on the index page", context do
        # Create via UI first (surface layer only)
        {:ok, new_view, _html} = live(context.conn, "/things/new")
        new_view
        |> form("#thing-form", thing: %{name: "To Delete"})
        |> render_submit()

        {:ok, view, _html} = live(context.conn, "/things")
        assert render(view) =~ "To Delete"
        {:ok, Map.put(context, :view, view)}
      end

      when_ "user clicks delete", context do
        context.view
        |> element("a", "Delete")
        |> render_click()

        :ok
      end

      then_ "the thing is removed from the list", context do
        refute render(context.view) =~ "To Delete"
        :ok
      end
    end
  end
end
```

---

## Configuration

Application-level config for SexySpex behavior:

```elixir
# config/test.exs
config :sexy_spex,
  manual_mode: false,    # Enable interactive step-by-step execution
  step_delay: 0          # Milliseconds to pause between steps (useful for visual testing)
```
