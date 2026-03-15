# Dotenvy — Environment Variable Configuration

## Sources
- https://hexdocs.pm/dotenvy/readme.html
- https://hexdocs.pm/dotenvy/Dotenvy.html

---

## Overview

Dotenvy loads `.env` files and provides type-casting access via `env!/2` and `env!/3`. Zero dependencies. All configuration goes in `config/runtime.exs` — the only config file that runs in both mix and release contexts.

---

## Project Setup

### Dependency

```elixir
# mix.exs
{:dotenvy, "~> 1.1.0"}
```

### File layout

```
envs/
├── .env          # Shared defaults (all environments)
├── dev.env       # Dev-specific values
├── test.env      # Test-specific values
└── prod.env      # Production values
```

### Loading in runtime.exs

```elixir
import Config
import Dotenvy

# RELEASE_ROOT is set by mix release; falls back to ./envs for local dev
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")

source!([
  Path.absname(".env", env_dir_prefix),              # 1. Base defaults (lowest priority)
  Path.absname("#{config_env()}.env", env_dir_prefix), # 2. Environment-specific
  System.get_env()                                     # 3. Real env vars (highest priority)
])
```

**Precedence is left-to-right — rightmost wins.** `System.get_env()` goes last so real environment variables always override file values. This matters in production where the deploy sets `DATABASE_URL`, `SECRET_KEY_BASE`, etc. as real env vars.

Files that don't exist are silently skipped.

---

## `env!/2` — Required Variables

Reads from the merged source map. Raises if the variable is missing.

```elixir
config :my_app,
  github_client_id: env!("GITHUB_CLIENT_ID"),
  github_client_secret: env!("GITHUB_CLIENT_SECRET"),
  deploy_key: env!("DEPLOY_KEY")
```

Without a type argument, returns the raw string. The app won't boot if any of these are missing — fail fast.

---

## `env!/3` — Variables with Defaults

If the variable is **missing entirely**, returns the default **as-is without type conversion**. If the variable **exists** (even as empty string), type conversion is applied.

```elixir
config :my_app,
  base_url: env!("BASE_URL", :string, "https://dev.codemyspec.com"),
  pool_size: env!("POOL_SIZE", :integer, 10),
  enable_workers: env!("ENABLE_WORKERS", :boolean, false)
```

---

## Type Casting Reference

Three suffixes control empty-string behavior:
- **No suffix** — type-specific default (e.g., `""` → `0` for integer, `false` for boolean)
- **`?` suffix** — nullable (`""` → `nil`)
- **`!` suffix** — required (`""` raises)

| Type | `""` behavior | Converts to |
|---|---|---|
| `:string` | Returns `""` | String (no conversion) |
| `:string?` | Returns `nil` | String or nil |
| `:string!` | **Raises** | String (non-empty required) |
| `:integer` | Returns `0` | Integer |
| `:integer?` | Returns `nil` | Integer or nil |
| `:integer!` | **Raises** | Integer (non-empty required) |
| `:float` | Returns `0.0` | Float |
| `:float?` | Returns `nil` | Float or nil |
| `:float!` | **Raises** | Float (non-empty required) |
| `:boolean` | Returns `false` | Boolean (`"false"`, `"0"`, `""` → false, all else → true) |
| `:boolean?` | Returns `nil` | Boolean or nil |
| `:boolean!` | **Raises** | Boolean (non-empty required) |
| `:atom` | Returns `:""` | Atom |
| `:atom?` | Returns `nil` | Atom or nil |
| `:atom!` | **Raises** | Atom (non-empty required) |
| `:existing_atom` | **Raises** | Existing atom only (safe) |
| `:existing_atom?` | Returns `nil` | Existing atom or nil |
| `:existing_atom!` | **Raises** | Existing atom (non-empty required) |
| `:module` | **Raises** | Module name (prepends `Elixir.`) |
| `:module?` | Returns `nil` | Module or nil |
| `:module!` | **Raises** | Module (non-empty required) |
| `:charlist` | Returns `''` | Charlist |
| Custom fn | N/A | Any arity-1 function |

### Custom type function

```elixir
# Comma-separated list
allowed_origins: env!("ALLOWED_ORIGINS", fn val -> String.split(val, ",") end, [])

# Atom from known set
log_level: env!("LOG_LEVEL", fn val -> String.to_existing_atom(val) end, :info)
```

---

## Common Patterns

### Required secrets (no default)

```elixir
github_client_id: env!("GITHUB_CLIENT_ID"),
github_client_secret: env!("GITHUB_CLIENT_SECRET"),
secret_key_base: env!("SECRET_KEY_BASE")
```

App crashes at boot if any of these are missing. This is intentional.

### Optional with sensible default

```elixir
base_url: env!("BASE_URL", :string, "https://dev.codemyspec.com"),
pool_size: env!("POOL_SIZE", :integer, 10),
port: env!("PORT", :integer, 4000)
```

### Truly optional (nil when absent)

```elixir
vapid_public_key = env!("VAPID_PUBLIC_KEY", :string, nil)
vapid_private_key = env!("VAPID_PRIVATE_KEY", :string, nil)

if vapid_public_key && vapid_private_key do
  config :web_push_elixir,
    vapid_public_key: vapid_public_key,
    vapid_private_key: vapid_private_key
end
```

### Conditional config blocks

```elixir
if config_env() == :prod do
  database_url =
    System.get_env("DATABASE_URL") ||
      raise "environment variable DATABASE_URL is missing."

  config :my_app, MyApp.Repo,
    url: database_url,
    pool_size: env!("POOL_SIZE", :integer, 10)
end
```

### Runtime config from Dotenvy, compile-time in dev/test.exs

Dotenvy lives in `runtime.exs`. Static config like database credentials for dev can stay in `config/dev.exs` using plain values:

```elixir
# config/dev.exs — static, no Dotenvy
config :my_app, MyApp.Repo,
  username: "postgres",
  password: "postgres",
  database: "my_app_dev"
```

Secrets and environment-dependent values go in `runtime.exs` via Dotenvy.

---

## `.env` File Syntax

```bash
# Comments
KEY=value
QUOTED="value with spaces"
SINGLE_QUOTED='literal $value no interpolation'
MULTI_LINE="line1\nline2"
INTERPOLATION="${OTHER_VAR}/suffix"
EMPTY_VALUE=
```

Variable interpolation (`${VAR}`) resolves against values already loaded in the source chain. System env vars used in interpolation must appear in a source **before** the file that references them.

---

## `source!/1` Options

```elixir
source!(sources, opts \\ [])
```

| Option | Type | Default | Description |
|---|---|---|---|
| `:require_files` | boolean or list | `false` | Raise if listed files are missing |
| `:parser` | module | `Dotenvy.Parser` | Custom parser module |
| `:side_effect` | function | process dict | Custom arity-1 fn called after parsing |

```elixir
# Require the base .env file to exist
source!([".env", "#{config_env()}.env", System.get_env()], require_files: [".env"])
```

---

## Path Resolution

Always use absolute paths. Relative paths break in releases and Livebook.

```elixir
# For project-root-relative envs/ directory
env_dir_prefix = System.get_env("RELEASE_ROOT") || Path.expand("./envs")
Path.absname("dev.env", env_dir_prefix)

# For project root
dir_prefix = Path.expand("../", __DIR__)
Path.absname(".env", dir_prefix)
```

`RELEASE_ROOT` is set by `mix release` — it points to the release directory. In local dev, fall back to `Path.expand("./envs")` or similar.

---

## Differences from System.get_env

| | `System.get_env/1` | Dotenvy `env!/2` |
|---|---|---|
| Source | OS env vars only | `.env` files + maps + OS env vars |
| Types | Always string or nil | Casts to integer, boolean, float, atom, module, charlist |
| Missing vars | Returns `nil` silently | Raises with clear error message |
| Empty strings | Returns `""` | Configurable: keep, nil (`?`), or raise (`!`) |
| Defaults | Handle nil yourself | Built-in via `env!/3` |
| Layered files | Not supported | Multiple files with merge precedence |
| Interpolation | Not supported | `${VAR}` substitution within `.env` files |
