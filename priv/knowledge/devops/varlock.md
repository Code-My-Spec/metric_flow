# Varlock — Local-dev env hygiene

Varlock (varlock.dev, github.com/dmno-dev/varlock) is installed on the
laptop only, used for two things during local dev:

1. **Output redaction.** Run a command via `varlock run -- <cmd>` and
   any `@sensitive` env value gets replaced with `▒▒▒▒▒` in the
   command's stdout/stderr. Useful when copy-pasting terminal output to
   chats, transcripts, or screen-shares.
2. **Plaintext leak scanner.** `varlock scan` greps the repo for any
   plaintext occurrences of resolved sensitive values — catches an
   accidental paste of an API key into a test file.

Varlock is **not** in the deploy path. UAT and prod fetch their secrets
from AWS SSM Parameter Store at boot inside the running container — see
`secrets-runtime.md`.

## Install

Homebrew is the supported path on macOS:

```bash
brew install varlock
varlock --version  # should be 1.x
```

Linux: see varlock.dev/getting-started/installation. The npm package
also exists but we don't use it for this repo.

## Files

- `.env.schema` (committed) — declares the env vars metric_flow uses,
  with `@sensitive` decorators on the secret-bearing ones. No values.
- `.env`, `.env.dev`, `.env.test` (gitignored) — actual values for
  local dev. Created by hand or copied from `.env.example`.
- `priv/knowledge/devops/varlock.md` (this file) — what you're reading.

## Workflow

Wrap any command in `just run` to launch it under varlock:

```bash
just run iex -S mix phx.server
just run mix test
just run mix ecto.migrate
```

Without `just run`, your shell sees raw env values just like before —
varlock only filters *its own* child process output.

The leak scanner is a separate one-off:

```bash
just scan
```

## Limits and known quirks

- **Schema validation is best-effort.** Varlock auto-loads `.env`,
  `.env.<APP_ENV>`, etc., and refuses to launch a child if the schema
  flags any var as required-but-empty. The interaction with our
  existing `.env`/`.env.dev` split is not perfect — some recipes can
  exit non-zero with confusing "Value is required" messages even when
  the value is set somewhere varlock didn't look. Treat schema
  diagnostics as informational, not authoritative. If `varlock run`
  refuses to launch and the underlying command would actually work
  fine, fall back to running it directly.
- **Redaction is opt-in per command.** If you run `mix phx.server`
  directly (not through `just run`), terminal output is not redacted.
- **Dev-only by design.** Varlock does NOT run on the boxes. Don't add
  varlock to the Dockerfile — Elixir releases ship without Node and we
  want to keep it that way.

## Why we keep it despite the friction

The 2026-05-06 metric_flow UAT migration leaked a dozen secrets to a
session transcript because a buggy zsh substitution echoed env values.
That class of accident — operator-side stdout exposure — is exactly
what varlock's redaction prevents in *any* command launched under
`varlock run`. The schema validation is a bonus we don't fully rely on
yet.

## Adding a var

1. Edit `.env.schema` — add the variable name, mark `@sensitive` if
   it's a secret.
2. Add the dev value to your local `.env` (or `.env.dev`).
3. If the var is also needed in prod/uat, see `secrets-runtime.md` for
   how to put it in SSM at `/metric_flow/<env>/<KEY>`.

## References

- varlock.dev — main docs
- github.com/dmno-dev/varlock — source
- `secrets-runtime.md` (sibling) — UAT/prod architecture
