# Push to `origin main` refused 403 for `code-my-spec[bot]`

This note exists because nothing in this repository causes the refusal, so
no code change can fix it. A person has to fix the credential outside the
repo. The note records the error, the credential the push used, and what
was checked here, so whoever acts on it does not have to re-check the
repo first.

## Exact error (verbatim)

    remote: Permission to Code-My-Spec/metric_flow.git denied to code-my-spec[bot].
    fatal: unable to access 'https://github.com/Code-My-Spec/metric_flow.git/': The requested URL returned error: 403

## Credential the push used

The push was done as `code-my-spec[bot]` — a GitHub App installation token
for the `code-my-spec` App, presented to `https://github.com/...` over
HTTPS. The token itself is not in this repo and is not reproduced here.

## What was checked in this repository

Everything below was inspected at the HEAD this note is committed on. None
of it is a cause.

- **Remote URL.** `git remote -v` shows
  `origin  https://github.com/Code-My-Spec/metric_flow.git` for both fetch
  and push. That is the same URL that appears in the 403, so the request
  is reaching the intended repository — there is no wrong-remote or
  typo'd-host case.
- **In-repo git config** (`.git/config` for this worktree and the shared
  `.git/` it points at). Only `core.*`, `remote.origin.url`,
  `remote.origin.fetch`, `branch.main.{remote,merge}`, and
  `submodule.recurse=true` are set. No `credential.helper`, no
  `url.<base>.insteadOf`, no `http.extraHeader`, no `http.<url>.*`
  override, no `push.default`/`receive.*` that could redirect the push or
  substitute a different identity.
- **Tracked files that could set git config or rewrite URLs.** A repo-wide
  grep for `credential.helper`, `insteadOf`, and `extraHeader` finds no
  occurrence outside `issues/push-origin-main-403.yml` (the issue text
  itself) and `docs/github-app-permissions.md` (prose that explicitly
  documents their *absence*). No `.gitattributes`, no `.git-credentials`,
  no `.netrc`, no `CODEOWNERS` is tracked anywhere in the tree.
- **Pre-push / server-side hooks under version control.** There is no
  `hooks/` directory committed anywhere in the tree; the only paths named
  `hooks` are Phoenix `LiveView` / JS hook directories under `lib/`,
  `test/`, `assets/js/`, and `.code_my_spec/spec/`, none of which git runs.
  `.git/hooks/` is not tracked (git never tracks it) and is the shared
  worktree's default, un-customised set of `*.sample` files.
- **Workflows this repo controls.** `.github/workflows/` holds exactly
  two files, `ci.yml` and `build.yml`. Neither runs `git push`: `ci.yml`
  only runs `just ci` and the report step, `build.yml` only builds and
  pushes a container image to GHCR. The commits in `origin/main..HEAD`
  touch no files under `.github/workflows/`, so the push does not need
  the App's `Workflows: Write` scope — this is not a workflows-scope
  refusal.
- **Branch-protection / ruleset files under version control.** None
  exist. Branch protection and rulesets for `main` are configured on
  GitHub and are not represented by any tracked file in this repo, so
  nothing in the repo can turn them off or add an actor to an allow list.
- **The push recipe.** `justfile` has no `git push` recipe (the only
  `git` calls are `git worktree add` and `git -C ... submodule update`),
  `bin/` contains `backup` and `deploy` (no push to GitHub), and
  `.code_my_spec/tasks/code_generation.sh` does not push. The push that
  produced the 403 is run by the CodeMySpec harness outside this working
  tree, not by any committed script here.

## Why the cause is not in this repo

For a repo-side cause to exist, the 403 would have to come from something
this repository could change: a different remote URL, an in-repo credential
helper or URL rewrite that swaps the token at push time, a committed hook
that rejects the push locally, a workflow doing the push under a different
token, or a branch-protection / CODEOWNERS file the repo owns. Every one
of those is checked above and is not set. The remaining surface — who the
`code-my-spec` GitHub App installation lets write `Code-My-Spec/metric_flow`,
and what branch protection on `main` requires — lives entirely on GitHub
and is not something a commit here can change.

Earlier diagnoses on the sibling `push-origin-dev-*` issues named a specific
GitHub-side permission as the cause. This note deliberately does not repeat
that claim: the three prior landings did not resolve the push, which is
evidence those diagnoses were not the whole story. Pinning the exact
external cause is a person's job, not this note's; this note's job is only
to establish that it is not in-repo.

## What a person needs to do

Fix the credential or its access outside this repository. The error is
emitted at the HTTPS layer by `github.com` before any repo content is
consulted, so the resolution is on GitHub (or on whatever generates /
injects the installation token for the harness), not here. Do not open a
code change in this repo to "fix" this 403 — there is nothing here to
change.
