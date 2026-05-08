# MetricFlow operator surface — `just <recipe>`.
#
# Two scopes:
#  - DEV: `just run <cmd>` wraps a command in `varlock run` so `@sensitive`
#    values are redacted in stdout/stderr. Useful for `mix phx.server`,
#    `iex -S mix`, etc., when you want leak protection in your terminal.
#    Schema validation is currently best-effort (varlock auto-loading
#    doesn't play perfectly with the existing .env/.env.dev split — see
#    priv/knowledge/devops/varlock.md).
#  - DEPLOY: thin wrappers over scripts/deploy*. Operator-side env
#    injection still uses `render-env` until ex_aws_ssm wiring in
#    runtime.exs lands and lets the deployed app fetch its own secrets
#    (see priv/knowledge/devops/secrets-runtime.md).
#
# Tooling:
#  - varlock: `brew install varlock` (system binary).
#  - kamal:   ruby gem on PATH.

set shell := ["bash", "-uc"]

# Show every recipe.
default:
    @just --list

# === DEV =====================================================================

# Run a command under varlock so `@sensitive` env values are redacted in
# its stdout/stderr.
#   just run iex -S mix phx.server
run *cmd:
    varlock run -- {{cmd}}

# Scan the repo for accidental plaintext occurrences of `@sensitive` env
# values (e.g. an API key copy-pasted into a test file).
scan:
    varlock scan

# === DEPLOY ==================================================================

deploy:
    ./scripts/deploy

deploy-uat:
    ./scripts/deploy-uat
