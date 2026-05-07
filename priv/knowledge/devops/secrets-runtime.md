# Runtime secret loading on UAT and prod

The deployed metric_flow container fetches its own secrets from AWS SSM
Parameter Store at boot, via `MetricFlow.Secrets.load!/1` called from
the top of `config/runtime.exs`. Kamal carries only AWS bootstrap
credentials — never the app's secrets themselves.

This article covers the architecture, the IAM setup the container
needs, and how to add or rotate a secret. For local-dev hygiene see
`varlock.md` (sibling file).

## Why this design

Operator-side env injection (the prior `render-env` script) had a real
flaw: every secret got sourced into the operator's interactive shell
before Kamal ran. A buggy substitution echoed all of them to a session
transcript on 2026-05-06 — full leak. Fetching at runtime inside the
container removes that vector. The only thing that touches the
operator's shell is the AWS access key, and even that doesn't have to
be passed through the laptop if a sufficiently-scoped IAM role is on
the operator's `~/.aws/credentials`.

## Flow

```
laptop                                      Hetzner box
┌────────────────────────┐                  ┌───────────────────────────┐
│  just deploy           │                  │  docker run image:<sha>   │
│   └─ kamal deploy ...  │   SSH+docker run │   --env APP_ENV=prod      │
│      (passes AWS_*     │ ───────────────► │   --env AWS_ACCESS_KEY... │
│       env.secret)      │                  │   ...                     │
└────────────────────────┘                  │                           │
                                            │  BEAM starts:             │
                                            │   runtime.exs             │
                                            │    └─ MetricFlow.Secrets  │
                                            │        .load!("prod")     │
                                            │        ▲                  │
                                            │        │ ExAws.SSM        │
                                            │        ▼                  │
                                            └────────┼──────────────────┘
                                                     │
                                                     ▼
                                       AWS SSM /metric_flow/prod/*
```

Kamal's job in this design is just: ship the right image to the right
box with `APP_ENV` set and AWS bootstrap creds in env. The container
does the rest.

## Files

- `lib/metric_flow/secrets.ex` — the loader. Pulls every parameter
  under `/metric_flow/<APP_ENV>/`, trims the path prefix, and
  `System.put_env/2`'s each one. Subsequent `Dotenvy.env!/3` calls
  pick them up.
- `config/runtime.exs` — calls `MetricFlow.Secrets.load!/1` BEFORE
  the existing `Dotenvy.source!([System.get_env()])` line. Order
  matters: secrets must be in System env before source!() runs.
- `config/deploy.yml` — Kamal config. `env.secret` lists only the AWS
  bootstrap creds. `env.clear` sets `APP_ENV=prod` and `AWS_REGION`.
- `config/deploy.uat.yml` — same shape, `APP_ENV=uat`.
- `lib/metric_flow/release.ex` — release task helpers (migrations).
  Unchanged by this work.

## IAM

The container needs an IAM principal that can:

- `ssm:GetParametersByPath` on `arn:aws:ssm:us-east-1:889081505590:parameter/metric_flow/*`
- `kms:Decrypt` on the SSM service KMS key (the default `aws/ssm` key,
  free, encrypts SecureString parameters at rest)

Currently the box's IAM user `hetzner-secrets-reader` has read-all
permission on every SSM path under the account. We pass that user's
access key + secret to the container via Kamal `env.secret`. Tighter
scoping is possible (a `metric-flow-prod-app` IAM user scoped to
`/metric_flow/prod/*` only) — deferred to follow-up.

The access key + secret need to be present in the operator's
environment when running `kamal deploy`. Sources, in order of
preference:

1. **Read from `/opt/shared/secrets-reader.env` on the box** — the
   creds already live there. Operator's deploy script SSHes, reads the
   file, exports into local env, then runs Kamal. (Future improvement;
   the current setup uses option 2 below.)
2. **Operator's `~/.aws/credentials`** — passes the laptop's AWS
   creds to the container. Works but is broader-scoped than the
   container needs.

## Adding or rotating a secret

```bash
# Add or update a value
aws ssm put-parameter \
  --name /metric_flow/prod/SOME_KEY \
  --value 'the-new-value' \
  --type SecureString \
  --overwrite

# Verify it's readable (use the path-list, not get-parameter, to keep
# the value out of stdout)
aws ssm get-parameters-by-path --path /metric_flow/prod \
  --recursive --query 'Parameters[].Name' --output text | tr '\t' '\n'

# Roll the running container so it picks up the new value
just deploy
```

`MetricFlow.Secrets.load!/1` runs once at boot. There is no live
re-fetch — rotation requires a restart of each container. For the
Kamal-deployed app, that's a redeploy.

## Local dev does NOT use this path

`config/runtime.exs` only calls `MetricFlow.Secrets.load!/1` when
`config_env() == :prod`. In `:dev` and `:test`, `Dotenvy.source!/1`
loads from local `.env` files as before. Local dev never needs AWS
credentials.

## Adding a brand-new env

If you add a third env (e.g. `staging`):

1. Provision a database + per-app DB user on the staging box (via
   `~/Documents/github/devops/scripts/provision-db metric_flow staging`).
2. Seed the SSM tree at `/metric_flow/staging/*` (mirror prod's keys).
3. Add `lib/metric_flow/secrets.ex`'s guard:
   `def load!(app_env) when app_env in ["prod", "uat", "staging"]`.
4. Create `config/deploy.staging.yml` with `APP_ENV: staging`,
   `proxy: false`, and the right host/network-alias.
5. Add a Caddyfile route + DNS record for the new domain.

## Failure modes

- **No SSM parameters under path** — `MetricFlow.Secrets.load!/1`
  raises with a clear message. Container exits, Kamal marks the
  deploy failed.
- **AWS creds missing** — `ExAws` returns
  `{:error, :no_credentials}`. Container exits.
- **AWS region wrong** — `ExAws.request/1` returns an HTTP error.
  Container exits. Set `AWS_REGION` in `env.clear` of the deploy yaml.
- **SSM rate-limited** — unlikely at our volume. If we hit it, the
  loader doesn't retry; bring back with a fresh deploy.

## References

- `lib/metric_flow/secrets.ex` — the loader source
- `~/Documents/github/devops/infra.md` — SSM layout and per-app paths
- ex_aws_ssm: hex.pm/packages/ex_aws_ssm
- AWS SSM Parameter Store: docs.aws.amazon.com/systems-manager/latest/userguide/systems-manager-parameter-store.html
