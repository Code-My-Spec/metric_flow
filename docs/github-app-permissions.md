# Push access for `code-my-spec[bot]`

CodeMySpec's harness pushes landed work to `origin dev` on
`https://github.com/Code-My-Spec/metric_flow.git`. The push authenticates as
the `code-my-spec` GitHub App (identity shows as `code-my-spec[bot]`), and
must not be refused.

What this repository controls ends at the remote URL — the App installation,
its repository selection, its permissions, and any branch protection on
`dev` are all on GitHub and need a human with admin on the
`Code-My-Spec` organization to grant them.

## Status: still blocked (not fixed in-repo)

`push-origin-dev-403` landed as a docs-only change (`d450452d`) and the next
landed work (`push-origin-dev-403-2`) saw the push still refused with the
same verbatim message:

    remote: Permission to Code-My-Spec/metric_flow.git denied to code-my-spec[bot].
    fatal: unable to access 'https://github.com/Code-My-Spec/metric_flow.git/': The requested URL returned error: 403

Everything this repository can decide is already right (see *What this
repository already has right* below). The refusal is a GitHub-side grant
that only a human admin on the `Code-My-Spec` organization can make, and
until that grant happens no change in this repo will make the push succeed.
This commit does not claim to fix the push; it narrows the diagnosis to the
one permission that is actually missing and names the page on which it is
granted.

### Exactly one permission is missing

The one grant that must be made: set the `code-my-spec` App installation's **Contents** permission to **Read and write** on `Code-My-Spec/metric_flow`.

The wire error — a flat `403` carrying `Permission to <repo>.git denied to
<app>[bot]` and no `GH006` prefix — is GitHub's response for a GitHub App
that either is not installed on the target repository or is installed
without `Contents: Write`. Branch protection would answer with `GH006:
Protected branch update failed`, not this flat 403, so the rule on `dev` is
not the cause; a suspended App would say so in the UI and surface a
distinct error on push, which is also not what we see. That leaves exactly
one thing to grant:

- **On**: the `code-my-spec` GitHub App's *installation* on
  `Code-My-Spec/metric_flow` (the per-repository installation, not the App
  definition).
- **Where**:
  <https://github.com/organizations/Code-My-Spec/settings/installations> →
  open `code-my-spec` → **Configure**.
- **What**: under **Repository access**, `metric_flow` must be in the
  selected repositories (or "All repositories" must be chosen); and under
  **Repository permissions**, **Contents** must be set to **Read and
  write**. Save; GitHub will prompt the admin to accept the permission
  change.
- **Who**: a member of `Code-My-Spec` with the **Owner** role on the
  organization (or any member with the `manage_installations` fine-grained
  permission). A repository admin without org-level rights cannot change
  an org-installed App's permissions.

That single grant is both necessary and sufficient for this exact error.

## How to confirm the grant worked

From a checkout of `main` at the current HEAD, with the harness's GitHub
App installation token in the environment the harness uses for `git push`:

    git push origin HEAD:refs/heads/dev

It should report either `Everything up-to-date` or a fast-forward update
of `dev`, with no `403` and no `Permission ... denied` line.

## What this repository already has right

- `origin` points at `https://github.com/Code-My-Spec/metric_flow.git`
  (the URL in the 403), so there is no wrong-remote case to rule out.
- The commits the harness is pushing (everything in `origin/dev..main`)
  touch no files under `.github/workflows/`, so the push does not require
  the App's `Workflows: Write` scope and this is not a workflows-scope
  refusal.
- Nothing in this repo sets a credential helper, a `url.*.insteadOf`
  rewrite, or an `http.extraHeader` that could redirect the push or
  substitute a different token; the harness supplies the token directly
  to `git push`.

## Other GitHub-side settings worth checking once the grant is made

These are not the cause of the current 403 (the error format rules them
out), but they are the next things to trip over once `Contents: Write` is
granted and the push gets past the repo-level check:

1. **Branch protection on `dev` does not exclude the bot.** Visit
   <https://github.com/Code-My-Spec/metric_flow/settings/branches>, open
   the rule covering `dev`, and either leave the rule off entirely (the
   harness owns that branch and is the only writer), or under **Restrict
   who can push to matching branches** add `code-my-spec[bot]` to the
   allow list, and under **Allow specified actors to bypass required pull
   requests** add it too if PRs are required. A branch-protection refusal
   would come back as `GH006: Protected branch update failed`.

2. **The App is not suspended.** The org installations page shows a
   "Suspended" badge if so; click **Unsuspend**.
