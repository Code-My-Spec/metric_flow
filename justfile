# MetricFlow operator surface — `just <recipe>`.
#
# Two scopes:
#  - DEV: dev/test secrets are sops-encrypted in envs/{dev,test}.enc.env.
#  - DEPLOY: CodeMySpec deploys via bin/deploy; these are the by-hand
#    equivalents. Secrets are sops-encrypted in envs/<env>.enc.env.
#
# Tooling:
#  - kamal:   ruby gem on PATH.

set shell := ["bash", "-uc"]

# Show every recipe.
default:
    @just --list

# === DEV =====================================================================

# Bring the application back up on the code that is now checked out.
#
# CodeMySpec's promote runs this in the checkout it merged into and reads the
# exit status: non-zero means nothing is served. The app starts its own
# Cloudflare tunnel (config :metric_flow, :cloudflare_tunnel), so the preview
# URL answers only while this server is up.
restart:
    #!/usr/bin/env bash
    set -euo pipefail
    port="${PORT:-4070}"

    elixir -S mix deps.get
    MIX_ENV=dev elixir -S mix compile
    MIX_ENV=dev elixir -S mix ecto.migrate

    pids="$(lsof -ti tcp:"$port" -sTCP:LISTEN || true)"
    if [ -n "$pids" ]; then kill $pids; fi
    for _ in $(seq 1 30); do lsof -ti tcp:"$port" -sTCP:LISTEN >/dev/null || break; sleep 1; done

    mkdir -p tmp
    MIX_ENV=dev PORT="$port" nohup elixir -S mix phx.server > tmp/phx_server.log 2>&1 &

    for _ in $(seq 1 120); do
        if curl -s -o /dev/null "http://127.0.0.1:$port/health"; then
            echo "✓ metric_flow answering on $port"
            exit 0
        fi
        sleep 2
    done
    echo "✗ metric_flow did not answer on $port within 4 minutes — see tmp/phx_server.log" >&2
    exit 1

# Story 1108 (CodeMySpec): run *this* checkout's own app in the foreground,
# on whatever it's given.
#
# No parameters — the caller (CodeMySpec's harness) sets PORT and
# DATABASE_NAME as environment before invoking this, rather than positional
# args, so every app's `serve` recipe can take exactly what it needs without
# agreeing on one shared signature.
#
# Not a rework of `restart` above: that one is for the one server everyone
# shares, self-daemonizes because nothing is left holding it, and always
# rebuilds/migrates first because a pull might have moved either. This one is
# a working copy's own instance, called by something that already knows how
# to background a process and track its pid — so it stays in the foreground
# and lets the caller decide when it dies. Deps are assumed current; the
# harness runs `deps.get`/`compile` itself before a working copy's first use.
serve:
    #!/usr/bin/env bash
    set -euo pipefail

    : "${PORT:?PORT must be set}"
    : "${DATABASE_NAME:?DATABASE_NAME must be set}"

    if ! MIX_ENV=dev mix loadpaths >/dev/null 2>&1; then
        MIX_ENV=dev mix deps.get
        MIX_ENV=dev mix deps.compile
    fi

    if [ -f assets/package.json ] && [ ! -d assets/node_modules ]; then
        MIX_ENV=dev mix assets.setup
    fi

    MIX_ENV=dev mix ecto.create
    MIX_ENV=dev mix ecto.migrate
    exec env MIX_ENV=dev elixir -S mix phx.server

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
    bin/deploy prod

deploy-uat:
    bin/deploy uat
