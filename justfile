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

# === WORKING COPIES ==========================================================

# Make a new working copy usable. CodeMySpec's harness calls
# `just init-worktree <name> <target>` when it creates one; without this
# recipe it falls back to a bare `git worktree add` plus submodules, and the
# copy arrives with no deps, no _build and no dotenv files.
#
# That fallback cost a night on 2026-09-24. A copy staffed with agents
# reported "This checkout cannot satisfy its own mix.lock", `mix format`
# died on Phoenix.CodeReloader (a Mix listener in our own mix.exs, absent
# because nothing had been compiled), and a clean test file read as five
# broken tests because .env.test was missing so its own guard clauses
# flunked. None of those look like configuration — they look like a broken
# platform or a bad edit, and agents filed them as such.
#
# `deps` is copied rather than fetched because `mix deps.get` in a fresh
# worktree dies on our shallow (depth: 1) git deps with
# `fatal: unable to read tree <sha>` — the pinned commit is not in the
# shallow clone. mix.lock is committed, so the source checkout's deps
# already match it exactly; deps.get afterwards verifies that.
#
# Dev/test secrets are committed sops-encrypted in envs/ and decrypted here.
init-worktree name target:
    #!/usr/bin/env bash
    set -euo pipefail

    git worktree add -b "{{name}}" "{{target}}"
    git -C "{{target}}" submodule update --init --recursive

    cp -R deps "{{target}}/deps"

    # Dev/test secrets are committed sops-encrypted; sops reads the age key
    # from the machine keyring. Plain copy only where there is no
    # encrypted file to decrypt.
    for e in dev test; do
        if [ -f "envs/$e.enc.env" ]; then
            sops -d --input-type dotenv --output-type dotenv "envs/$e.enc.env" > "{{target}}/.env.$e"
        elif [ -f ".env.$e" ]; then
            cp ".env.$e" "{{target}}/.env.$e"
        fi
    done
    if [ ! -f envs/dev.enc.env ] && [ -f .env ]; then cp .env "{{target}}/.env"; fi

    cd "{{target}}"
    mix deps.get
    MIX_ENV=dev mix deps.compile
    MIX_ENV=test mix deps.compile

    echo "→ {{target}} ready: deps compiled for dev and test, dotenv copied where present"

# === DEPLOY ==================================================================

deploy:
    ./scripts/deploy

deploy-uat:
    ./scripts/deploy-uat
