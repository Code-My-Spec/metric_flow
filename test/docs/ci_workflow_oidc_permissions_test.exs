defmodule MetricFlow.Docs.CiWorkflowOidcPermissionsTest do
  @moduledoc """
  Guards the top-level `permissions:` block in `.github/workflows/ci.yml`
  that grants the CI job a GitHub Actions OIDC token.

  Without `id-token: write`, CodeMySpec's shared CI box refuses the
  `ci_report.sh` call with HTTP 403 because the job's GitHub OIDC token
  cannot prove which repository it runs for, and landed works sit at the
  ci step forever.
  """
  use ExUnit.Case, async: true

  @path ".github/workflows/ci.yml"

  setup_all do
    {:ok, body: File.read!(@path)}
  end

  test "grants id-token: write at the top level, not inside the job", %{body: body} do
    assert body =~ ~r/^permissions:\n(?:[ \t]+[^\n]*\n)*[ \t]+id-token:[ \t]+write/m,
           "#{@path} must declare `id-token: write` under a top-level `permissions:` block (beside `on:`), so the job receives a GitHub Actions OIDC token"
  end

  test "keeps contents: read at the top level", %{body: body} do
    assert body =~ ~r/^permissions:\n(?:[ \t]+[^\n]*\n)*[ \t]+contents:[ \t]+read/m,
           "#{@path} must declare `contents: read` under the same top-level `permissions:` block"
  end

  test "leaves the repository guard, runner, just ci and the report step env untouched", %{
    body: body
  } do
    assert body =~ "if: github.repository == 'Code-My-Spec/metric_flow'",
           "the repository guard on the ci job must stay as-is"

    assert body =~ "runs-on: [self-hosted, cms-ci]",
           "runs-on must stay as-is"

    assert body =~ "- run: just ci",
           "the `just ci` step must stay as-is"

    assert body =~ "$CODEMYSPEC_PLUGIN/bin/ci_report.sh",
           "the ci_report.sh step must stay as-is"

    assert body =~ "CMS_PROJECT_ID: ${{ vars.CMS_PROJECT_ID }}",
           "CMS_PROJECT_ID env on the report step must stay as-is"

    assert body =~ "CMS_DEPLOY_KEY: ${{ secrets.CMS_DEPLOY_KEY }}",
           "CMS_DEPLOY_KEY env on the report step must stay as-is"
  end
end
