# Runtime secret loading on UAT and prod

UAT and prod secrets live sops-encrypted in `envs/uat.enc.env` and
`envs/prod.enc.env`, committed to the repo and copied into the image. Each
environment has its own age key; CodeMySpec holds the private halves
(ProjectSecrets `age_private_key_<env>`) and delivers the right one to the
container as `SOPS_AGE_KEY`. `rel/overlays/bin/boot` (and `bin/migrate`)
run the release under `sops exec-env`, so `config/runtime.exs` reads
everything from the OS environment.

Replaced the AWS SSM (`/metric_flow/<env>/*`) boot-time fetch on 2026-09-29.

## Adding or rotating a secret

Use CodeMySpec's provisioning (secrets step) or `sops set` with that
environment's key:

    SOPS_AGE_KEY=<key> sops set envs/uat.enc.env '["NAME"]' '"value"'

Commit the file and deploy. Never commit a decrypted env file.

## Dev and test

`envs/dev.enc.env` and `envs/test.enc.env` use a separate recipient (see
`.sops.yaml`) and are decrypted from the local keyring by
`just init-worktree`.
