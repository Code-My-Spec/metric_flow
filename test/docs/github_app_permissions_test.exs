defmodule MetricFlow.Docs.GithubAppPermissionsTest do
  @moduledoc """
  Guards the one repo-side artifact that `push-origin-dev-403-2` could
  produce: a docs page that names the exact GitHub-side permission whose
  absence is refusing the harness's `git push origin dev` as
  `code-my-spec[bot]`.

  The push itself cannot be fixed in this repo (only a `Code-My-Spec` org
  admin can grant the installation permission), so this test does not try
  to push. It asserts the diagnosis is on disk and precise enough for that
  admin to act without ambiguity — which is the only thing that would have
  made `push-origin-dev-403`'s docs-only fix actually resolvable.
  """
  use ExUnit.Case, async: true

  @path "docs/github-app-permissions.md"

  setup_all do
    {:ok, body: File.read!(@path)}
  end

  test "names the single missing permission", %{body: body} do
    assert body =~ "Contents",
           "docs/github-app-permissions.md must name the `Contents` repository permission"

    assert body =~ "Read and write",
           "docs/github-app-permissions.md must name `Read and write` as the level that permission must be set to"
  end

  test "names the installation, not just the App", %{body: body} do
    assert body =~ ~r/installation/i,
           "docs must call out that the grant is on the per-repo installation, not the App definition"

    assert body =~ "Code-My-Spec/metric_flow",
           "docs must name the repository the installation targets"
  end

  test "points at the org installations settings page", %{body: body} do
    assert body =~
             "https://github.com/organizations/Code-My-Spec/settings/installations",
           "docs must link the org installations settings page where the grant is made"
  end

  test "rules branch protection and suspension out of this specific 403", %{body: body} do
    assert body =~ "GH006",
           "docs must explain that a branch-protection refusal would be `GH006`, not this flat 403"
  end

  test "does not claim the push is fixed", %{body: body} do
    assert body =~ ~r/not fixed|still blocked|does not claim to fix/i,
           "docs must explicitly state the push is still blocked and awaiting the GitHub-side grant"
  end

  test "records that three successive landings have all left the push refused", %{body: body} do
    for id <- ["push-origin-dev-403", "push-origin-dev-403-2", "push-origin-dev-403-3"] do
      assert body =~ id,
             "docs must name #{id} among the landings that did not move the GitHub-side state"
    end

    assert body =~ ~r/no change in this repo will make the push succeed/i,
           "docs must state plainly that no in-repo change will unblock the push, so a future landing cannot quietly pretend otherwise"
  end
end
