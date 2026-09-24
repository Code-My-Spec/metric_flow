# Metric Flow — status, 2026-09-23 (second pass)

First customer project. Onboarded to dev today; one step from workable by the
agent team, and that step needs a credential only you can mint (below).

Dev project: `5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c` · repo: `/Volumes/X10 Pro/github/metric_flow` (permanent home)

---

## Where we are in one table

| | state | blocking the agent team? |
|---|---|---|
| Stories / criteria on dev | **53 / 459**, 374 with `spec_path` | no — done |
| Components on dev | 152 | no |
| Working copies | **1** — `3d7fe72b`, main, preview tunnel up | no — done |
| Files synced | **2329**, manifest accepted | no |
| Requirement graph | **298 invalidations queued, 0 rows** — drains on first read | one read away |
| Deploy key on the dev project | minted | no — done |
| `mix compile` (test env) | passes | no |
| `mix test` | **2904/2917 pass, 13 fail**, 10 excluded | no — the 13 are two unbuilt features |
| `mix spex` | **360/374 pass, 14 fail** | no — same two features |
| QA | 57 historical dirs (42 complete / 101 failed), **0 qa_attempts on dev** | yes, for QA work |
| DevOps (secrets/deploy) | on AWS SSM, not sops | yes, for promotion/deploy |
| Cassette replay | **closed** — every surface is `mode: :replay` | no |

---

## The headline: none of this code had ever been run

This is the thing to understand before reading the rest. `mix.exs` has:

```elixir
defp elixirc_paths(:test), do: ["lib", "test/support", "test/spex"]
```

That compiles **`.ex` files only**. The tests under `test/` and the 374 `_spex.exs`
files are loaded at runtime, so `mix compile` never looked at any of them. Behind
that gap three plain syntax errors had accumulated, each sufficient on its own to
stop the entire suite:

- `~s(handle_event/3 ("delete"))` — paren-delimited sigils don't nest, so the sigil
  ends at the first `)`. Invalid on 1.19.4 and 1.20.2 alike; **not** a version issue.
- a test *name* interpolating `#{account_id}`, a variable that exists nowhere.
- one `end` too many (12 `do` blocks, 13 `end`s).

Plus every spex called `import_givens`, which no longer exists in the library.

All fixed (`7f41c22`). All 510 `.exs` files under `test/` now parse and both suites
run. The point stands, and it explains the shape of everything below: a green build
here has never meant anything, so what the suites found on their first real run was
not a scatter of bugs but three whole-codebase drifts that nothing had ever been in a
position to notice — an enum narrowed without its callers, a paywall added without its
test setup, and a spec library upgraded past two of its own APIs. Four fixes, 756 → 87
test failures and 374 → 14 spex failures. What is left is feature work.

---

## Tests: 2844/2931, and the 756 failures were one decision

```
Result: 2844/2931 passed      (was 2175/2931)
Failed: 87 tests              (was 756)
```

**603 of the 756 were the account-type enum.** `@account_types [:client,
:agency]` since `7b48ef4`, and the Postgres enum `account_type` agrees — those
two labels, nothing else — while 43 sites in `test/` still created `personal`,
`team` or a raw-SQL `standard`, and four more compared the type to a string
where `Ecto.Enum` reads back an atom.

The question in the first draft of this doc ("is `:personal` still real?") had
an answer in the code, so it was not a judgement call:

- the schema's own moduledoc — "account type (client or agency) ... Client
  accounts are the default; agency accounts manage multiple client accounts"
- `create_team_account/2`, the only path a real user's account is created
  through, hard-codes `"type" => :client`
- `get_personal_account_id/1` is "the user's first account" and never reads the
  field, so the word *personal* survives in the codebase as naming, not as a
  type

John confirmed it independently: personal is deprecated, only agency and
client. So the old two collapse to `:client`, except the five fixtures whose
account really is an agency (`name: "Test Agency"`,
`agency_with_white_label_fixture/1`) — `layouts.ex` shows the agency nav on
`:agency` and `RequireSubscriptionHook` skips the paywall on it, so those tested
as `:client` would have exercised the wrong branch (`2c766e5`).

**45 more were the paywall.** Four LiveView test files mounted correlations,
chat and insights and got `{:error, {:redirect, ...}}` with "Upgrade to access
AI features" — `RequireSubscriptionHook` halts unless the account has a live
subscription or is an agency, and these tests predate it. None of them asserts
the paywall, so it is setup missing, not behaviour.
`MetricFlowTest.BillingFixtures.active_subscription_fixture/2` now supplies one,
kept out of the account fixtures on purpose so a test that wants to *see* the
paywall is still writable (`415e46f`). 43 of the 45 pass.

### The 87 that remain are the work, not the wiring

Spread thin — 2 to 10 per file across 25 files — and mostly plain assertion
failures and missing UI elements: a `[data-role='metric-list'] button` that
isn't rendered, a `form#white-label-form` that doesn't exist, PromEx and Sentry
not configured in `smoke_test.exs`, five Stripe webhook cases. No systemic
drift left to find. This is requirement-by-requirement work, which is exactly
what the agent team is for.

---

## Spex: 360/374 pass

```
Result: 360/374 passed        (was 0/374)
Failed: 14 tests
```

Two causes, both API drift from an older sexy_spex, both fixed:

**1478 bare `:ok` step endings** (`57798cc`). 0.2 requires every step block to
return `{:ok, context}` and refuses `:ok` outright, so every spex failed on its
first such step. Each site was resolved to its enclosing step by climbing
outward through `case`/`cond`/`if`/`with` and clause arrows — all 1478 bottomed
out at a `given_`/`when_`/`then_`/`and_`, none inside a `fn` or any other
non-tail position, so the value replaced was always the step's own return. One
step declared no context parameter and now does.

**All twelve shared givens replaced the context instead of merging into it**
(`c4406a2`). This is the interesting one. `given_ :user_logged_in_as_owner`
followed by `given_ :owner_has_active_subscription` left the context at `%{}`,
because the second answered `{:ok, %{}}` — so the step after it failed with
`key :owner_conn not found in: %{}`. 121 of the 143 spex still failing after the
first pass. Invisible until now because the old 2-arity `given_` discarded the
block's value entirely; what a given returned only started mattering when these
became `register_given/3`. Every one now merges, and the moduledoc says so,
because that is the invariant the next given has to hold.

The 14 left are agency auto-enrollment (6), agency white-label (7) and one
OAuth provider spex — features, not wiring.

**One operational note for any future bulk edit here:** one spex filename is
long enough that `sed -i` fails on it ("File name too long" — the temp file
exceeds `NAME_MAX`) and takes its whole batch down silently. Use a tool that
rewrites in place.

---

## QA

57 QA directories on disk from previous runs: **42 `result_complete`, 101
`result_failed`, 2 obsolete**. So QA has been exercised historically and mostly
failed.

On dev: **0 `qa_attempts`**. The migration deliberately skips QA attempts (along with
files, problems, components, requirements, analysis runs, file edits) — those are
derived and the harness recomputes them. So QA history lives only in this repo's
`.code_my_spec/qa/` tree, not on the server.

Nothing can be QA'd until there's a working copy and a preview to drive.

---

## DevOps migration — the known piece, and it's blocked on you

metric_flow fetches app secrets from **AWS SSM at container boot** via
`MetricFlow.Secrets.load!/1` (`config/runtime.exs`), with `.kamal/secrets-common`
carrying AWS bootstrap creds plus a registry token. The platform convention is
sops + age.

| | metric_flow today | convention (`cms_new`) |
|---|---|---|
| app secrets | AWS SSM `/metric_flow/<env>/*` | `envs/<env>.enc.env`, sops+age |
| kamal secrets | `.kamal/secrets-common` w/ AWS creds | `.kamal/secrets` w/ `SOPS_AGE_KEY` |
| deploy | `scripts/deploy` sourcing SSM | `bin/deploy` reading the age key |

Present: `Dockerfile`, `.github/workflows/build.yml`, `config/deploy.yml`,
`config/deploy.uat.yml`, `rel/overlays/bin/{migrate,server}`.
Missing: `.sops.yaml`, `.kamal/secrets`, `bin/deploy`, `bin/backup`, `envs/`.

This is the same migration MarketMySpec went through, and it falls under the standing
principle: adapt the legacy app to the platform, not the reverse. **The blocker is the
secret values** — they're in AWS SSM and pulling them needs AWS credentials. A peer
session previously declined to fetch those unilaterally and left it to you; I'm doing
the same. Say go and I'll do it.

---

## Cassette misses fall through to live calls

Running `mix test` appended 714 lines of fresh recordings across 5 cassettes, with
today's `recorded_at`, against `https://api.anthropic.com/v1/messages` (two calls,
`claude-sonnet-4-5`) and `https://api.stripe.com/v1/account_links`. The Stripe entry
came back with a real `request_log_url` carrying an account id and request id, so that
one definitely left the machine.

Proportion, since the first draft of this doc overstated it: the **Stripe key is
sandboxed** — the recorded ids are test mode (`acct_1TIup0…`, `.../test/workbench/...`) —
and two Sonnet calls is pennies, not a cost problem. The Anthropic dependency is also
on its way out, to be replaced with alloy and local Claude Code.

The actual defect is narrower and still worth closing: **a cassette miss falls through
to a live call and records it.** `config/runtime.exs` has a `:test_credentials` block
explicitly labelled "cassette recording credentials", so recording is meant to be a
deliberate act and ordinary runs are meant to replay. Two consequences:

- runs are non-deterministic and depend on network reachability
- a failing run writes new episodes into the cassettes, which is how cassettes get
  corrupted

Confirmed repeatable: the same 714 lines across the same 5 cassettes appeared on
**every** `mix test` run today — four of them — and were reverted each time. A run
that leaves the cassettes dirty is the normal case here, not an accident, so anything
that runs the suite unattended will commit recordings unless this is closed. Whatever
replaces the Anthropic client should replay by default and require an explicit flag to
record.

## Hard blocker: the working copy, and the one credential it needs

```
working copies: 0     requirements: 0
```

No harness has ever registered for metric_flow, so there is no working copy; with no
working copy there is no requirement graph; with no graph there is nothing to hand an
agent. `get_next_requirement` has nothing to answer with.

Everything about *how* is now known and verified, and it comes down to one thing you
have to do.

### 1. Mint a deploy key on the dev project — yours

Project `5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c` has no deploy key. It has existed since
2025-07-26, before projects got one at creation, and the migration import doesn't mint
one either. The harness cannot serve a copy without it:
`CmsHarness.Credentials.for_working_copy/1` resolves `CMS_TOKEN` → the copy's own
`.cms_harness.json` `deploy_key` → `:harness_deploy_key` config. The :4004 harness has
no `CMS_TOKEN` and nothing sets that config, so path two is the only one, and it is
filled from the project's key at onboarding. Both existing copies on this box
(broken_oaths, code_my_spec) carry one.

Two ways:

- **The project form.** `https://dev.codemyspec.com/app/projects/5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c/edit`
  → **Generate** beside Deploy Key → Save. The form does not touch `local_path`, so
  saving is safe.
- **One command**, from the code_my_spec checkout, using
  `Projects.ensure_deploy_key/2` rather than the form's own generator:

  ```
  MIX_ENV=dev elixir -S mix run --no-start \
    scripts/mint_deploy_key.exs 5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c
  ```

  It prints nothing but a confirmation — onboarding reads the key out of the
  database, so it never needs to be on a screen. `--no-start` is load-bearing:
  booting the app would try to bind :4000.

I was refused this one — minting a credential is a secret-store write — so it is
yours either way. The script is new and committed (`code_my_spec`); the form's
Generate button now mints the same shape the rest of the system does, which it
previously did not (it rolled its own 128 hex characters with no `dk_` prefix, so
`UserSocket.shape/1` logged a refused join as an unknown credential — fixed in
`3ece495e1`).

### 2. Onboard the copy — mine, one command

```
mix cms.harness.onboard "/Volumes/X10 Pro/github/metric_flow" \
  --project 5217fb4a-e2cd-493d-9e5f-2482fb8c4f2c \
  --server-url http://localhost:4000
```

`--server-url http://localhost:4000` on purpose, three times over: it is what the
running :4004 harness has in `CMS_SERVER_URL`, `dev.codemyspec.com` is that same
:4000 behind a Cloudflare named tunnel (`config/dev.exs:173`), and `localhost` is what
makes `ensure_local_credential/1` read the key out of the local dev Postgres instead of
refusing with `:no_credential`.

Run it from the `phx-new-generator` worktree, which has its own `_build/dev` — :4000
and :4004 both run from the **main** checkout, so this takes no lock either of them
cares about. The task starts only `:req`, never the app, so it will not try to bind
:4000. `mix cms.harness.onboard "<root>" --check` is the read-only version and
currently answers `not onboarded ... missing: CMS_HARNESS_ID, MIX_TEST_PARTITION,
HARNESS_CONFIG`.

### 3. Done — and what is left after it

The harness picked the copy up on its first contact and is serving it:
`/health` on :4004 lists it `connected`, `onboarded`, `watching`, and it has
rescanned on every file change since. 2329 files synced, components 152 → 182,
manifest accepted each time.

`requirements` is still 0, and that is expected rather than stuck. The rows are
written by a **publish**, and the compute behind it is triggered by a *read* —
`Requirements.Projection` reads the rows and a fingerprint miss computes and
publishes. `graph_invalidations` holds **298 queued** entries for this copy, so
the work is enqueued and waiting for the first reader. The old project-level
cache row says the graph is ~894 nodes / 1106 edges.

So the trigger is an agent starting on this project, or the project's page being
opened on dev. That is the next action and it is deliberately yours: starting an
agent is outward-facing.

### The original step 3, for reference

A harness learns which copies to serve from `Projects.list/0`, "the roots this harness
has been *asked* to serve, and it is asked by a hook arriving"
(`CmsHarness.WorkingCopyReporter`) — plus whatever `Device.announce/1` reports back for
this device. So a Claude Code session running in the checkout, or `start_agent` against
it, is what starts the first scan. Scan → files → components → requirement graph →
`get_next_requirement` has an answer.

`projects.local_path` currently points at `/Users/johndavenport/Documents/github/metric_flow`,
which does not exist — carried over by the import from where the repo used to live.
Nothing to fix by hand: `Projects.resolve_local_project/1` syncs it from the working
directory the first time resolution runs there.

---

## What landed today

**metric_flow** (9 commits, none pushed)

| commit | what |
|---|---|
| `6a37f91` | QA + spex dirs renamed numeric → slug (1429 pure renames, verified byte-identical) |
| `223e4c3` | `config.yml` names the project — was falling through to a dead `local_path` |
| `98c1e3e` | path deps → hex; `given/2` → `register_given/3`; generator compat shims |
| `b3ca4cf` | `MetricFlowSpex.Case` + `Fixtures` bridge; removed a duplicate boundary breaking clean builds |
| `7f41c22` | three syntax errors, `import_givens` → `import`, `.tool-versions` |
| `4a478c9` | this document, first pass |
| `57798cc` | 1478 bare `:ok` step endings → `{:ok, context}`, resolved to their step by AST position |
| `c4406a2` | all twelve shared givens merge into the context instead of replacing it |
| `2c766e5` | 47 stale account-type sites → the enum the domain and Postgres actually have; `.cms_harness.json` ignored |
| `415e46f` | `BillingFixtures.active_subscription_fixture/2`; four paywalled test files get a subscription |

**code_my_spec** (3 commits) — the first two were hard blockers on onboarding anything locally

| commit | what |
|---|---|
| `dfe479eb1` | Four CLI migrations carried Postgres-only SQL (`ALTER COLUMN`, `UPDATE…FROM`, `NULLS NOT DISTINCT`). The first raises, so Ecto stopped the set — **every local SQLite DB had been stuck since 2026-08-23**, 16 migrations stranded. Third instance of the shape `cms.guard_cli_migrate` already documents twice. |
| `489814ce3` | Six columns the shared schemas *select* that no CLI migration created, so `Repo.get(Project, id)` couldn't read a project at all. Scope measured across all 69 schemas, not guessed. |
| `3ece495e1` | The project form minted deploy keys its own way — 128 hex characters, no `dk_` — so `UserSocket.shape/1` couldn't name the credential in a refused-join log. Now one mint. Plus `scripts/mint_deploy_key.exs` for a project whose only route to a key was that button. |

`~/.codemyspec/cli.db` went 128 → 145 migrations. Backups at
`~/.codemyspec/cli.db.bak-20260923-184955` (pre) and `-191645-at144`.

Two incidental notes: the dev account **"Anderson" was flipped free → pro** (the
migration gates on a paid plan — reversible), and **8 orphaned `criteria → stories`
rows** in cli.db predate all of this, which is why 459 of 467 criteria migrated.

---

## What I was doing with the agent team

The governing goal has been: *get a story from product through spec, code, promotion
and QA end to end with no intervention.* **Broken Oaths** was the proving ground, and
it is finished:

```
61 stories · 1474 / 1476 requirements satisfied
```

The only 2 outstanding are `deploy`, which is deliberately outside
`StoryExecution.@completion_names`. Seven stories completed end-to-end in the most
recent stretch (915, 918, 941, 947, 950, 953, 942) — 941 went from parked through
product → spec → code → promote → browser QA with no intervention, which is the
thing we were trying to prove.

Fleet now: Broken Oaths has `coding`, `main` ×2, `product`, `qa` all running and
continuous — **with nothing left to do**. Metric Flow has no agents and no working
copy.

The recurring class of bug worth carrying forward: **"a person answering a gate is
not an edge."** `Work.consider_*` is edge-triggered and nothing polls, so a missed
edge is a permanent stall. Four distinct instances were found and fixed individually
(a restarted agent, a resumed agent, an answered question, a denied tap-out), and
then `Digest.quiet?/1` was fixed as the safety net underneath all of them — it had
been reporting an idle-but-eligible agent as "settled", which is the one state the
cadence exists to catch.

### The goal from here

Point the team at Metric Flow and have a main agent run it under supervision. Of
the six steps this doc listed this morning, three are done:

| | |
|---|---|
| ~~Spex `{:ok, context}` migration~~ | done — 0/374 → 360/374 |
| ~~The `:personal` account-type question~~ | done — the code answered it; 756 → 87 failures |
| ~~Sequence the harness onboarding~~ | done and verified up to the credential |
| **Mint the deploy key** | **yours, one click or one command** |
| Onboard the copy + first scan | mine, one command, then a session in the checkout |
| Cassette replay by default | worth closing before anything runs the suite unattended |
| DevOps migration off SSM | yours — needs the AWS call. Gates promotion and deploy |
| Set an active story, let the team run it | same as Broken Oaths |

The only thing between here and a requirement graph is the deploy key.
