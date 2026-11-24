# Push access for `code-my-spec[bot]`

CodeMySpec's harness pushes landed work to `origin dev` on
`https://github.com/Code-My-Spec/metric_flow.git`. The push authenticates as
the `code-my-spec` GitHub App (identity shows as `code-my-spec[bot]`), and
must not be refused.

What this repository controls ends at the remote URL — the App installation,
its repository selection, its permissions, and any branch protection on
`dev` are all on GitHub and need a human with admin on the
`Code-My-Spec` organization to grant them.

## What has to be true on GitHub

1. **The App is installed on the `Code-My-Spec/metric_flow` repository.**
   Visit
   https://github.com/organizations/Code-My-Spec/settings/installations,
   open the `code-my-spec` App, and under **Repository access** make sure
   `metric_flow` is in the list (either "All repositories" or "Only select
   repositories" including this one). An App that is not installed on a
   repo returns a flat `403 remote: Permission to <repo> denied to
   <app>[bot]` on any push to it.

2. **The installation grants `Repository permissions > Contents: Read and
   write`.** Same settings page, **Permissions & events**. Without
   `Contents: Write`, pushes are refused with the same flat 403 even when
   the App is installed.

3. **Branch protection on `dev` does not exclude the bot.** Visit
   https://github.com/Code-My-Spec/metric_flow/settings/branches, open the
   rule covering `dev`, and either:
   - leave the rule off entirely for `dev` (the harness owns that branch
     and is the only writer), or
   - under **Restrict who can push to matching branches**, add
     `code-my-spec[bot]` to the allow list, and under **Allow specified
     actors to bypass required pull requests** add it too if PRs are
     required.
   A branch-protection refusal would normally come back as `GH006:
   Protected branch update failed`, not the flat 403 we see; branch rules
   are listed here only because they are the second thing to trip over
   once the App is reinstalled.

4. **The App is not suspended.** Same org installations page shows a
   "Suspended" badge if so; click **Unsuspend**.

## What this repository already has right

- `origin` points at `https://github.com/Code-My-Spec/metric_flow.git`
  (the URL in the 403), so there is no wrong-remote case to rule out.
- The commits the harness is pushing (chat-responds-p0 plus its merge)
  touch no files under `.github/workflows/`, so the push does not require
  the App's `Workflows: Write` scope and this is not a workflows-scope
  refusal.
- Nothing in this repo sets a credential helper, a `url.*.insteadOf`
  rewrite, or an `http.extraHeader` that could redirect the push or
  substitute a different token; the harness supplies the token directly
  to `git push`.

## How to confirm the grant worked

From a checkout of `main` at the current HEAD, with the harness's
GitHub App installation token in the environment the harness uses for
`git push`:

    git push origin HEAD:refs/heads/dev

It should report either `Everything up-to-date` or a fast-forward
update of `dev`, with no `403` and no `Permission ... denied` line.
