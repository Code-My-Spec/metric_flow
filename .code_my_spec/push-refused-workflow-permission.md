# Push to `origin main` refused: GitHub App lacks `workflows` permission

This note exists because nothing in this repository causes the refusal, so
no code change here can fix it. A person has to grant the GitHub App's
token the `workflows` permission outside the repo. The note records the
exact error text, the credential the push used, what the fix is, and why
every push of `main` stays refused until that external fix lands.

## Exact error (verbatim)

    To https://github.com/Code-My-Spec/metric_flow.git
     ! [remote rejected]   HEAD -> main (refusing to allow a GitHub App to create or update workflow `.github/workflows/ci.yml` without `workflows` permission)
    error: failed to push some refs to 'https://github.com/Code-My-Spec/metric_flow.git'

## Credential the push used

The push was authenticated with a GitHub App installation token minted on
the server for the `code-my-spec` App. That token can push ordinary
commits to `Code-My-Spec/metric_flow`, but GitHub refuses any commit that
creates or updates a file under `.github/workflows/` unless the token also
carries the `workflows` permission. The token itself is not in this repo
and is not reproduced here.

## Why the cause is not in this repo

The preceding issue, `ci-report-proves-its-repository`, modified
`.github/workflows/ci.yml` (it added the top-level
`permissions: contents: read / id-token: write` block the CI report needs
in order to mint an OIDC token). That workflow-file change is what trips
the refusal: GitHub inspects the commit's tree, sees a touched
`.github/workflows/*` path, and gates it on the `workflows` scope the
token does not hold. The refusal is emitted by `github.com` before any
repo-side hook or script runs, so nothing committed here (no workflow,
no recipe, no hook, no config) can unblock it.

## What the fix is

Grant the `code-my-spec` GitHub App's installation token the `workflows`
permission — i.e. update the App's permissions on GitHub (and accept the
installation's permission upgrade on `Code-My-Spec/metric_flow`) so that
the installation token minted for pushes includes `Workflows: Write`.
That change lives on GitHub and on whatever server mints the token for
the CodeMySpec harness; it is **not** a code change in this repository.

Do not "fix" this by reverting or weakening the top-level `permissions:`
block in `.github/workflows/ci.yml`. That block (`contents: read`,
`id-token: write`) is required for the CI report's OIDC flow and must
stay.

## Why every push of `main` stays refused until then

`main` now contains the commit that modified `.github/workflows/ci.yml`.
GitHub's `workflows`-permission gate is evaluated against the set of
paths the push introduces into the branch's history, not just against
the tip commit's diff against the remote. As long as the token used to
push lacks the `workflows` permission, every push of `main` that carries
that commit (which is every push of `main` from now on, until the commit
is superseded on a branch the token *is* allowed to write) will be
refused with the same message. The block clears the moment the token
gains `workflows`; no further change in this repo is required.
