defmodule MetricFlow.CiWorkflowTest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../.github/workflows/ci.yml", __DIR__)

  test "ci-on-our-runner-deploys-uat: criterion 2 - CI runs on push to main, only on our runner and repo, and runs just ci" do
    assert File.exists?(@workflow), ".github/workflows/ci.yml does not exist"
    content = File.read!(@workflow)

    assert content =~ ~r/^on:\s*\n\s+push:\s*\n\s+branches:\s*\[\s*main\s*\]/m,
           "ci.yml does not trigger on push to main"

    assert content =~ ~r/runs-on:\s*\[\s*self-hosted\s*,\s*cms-ci\s*\]/,
           "ci.yml does not use runs-on: [self-hosted, cms-ci]"

    assert content =~ ~r/if:\s*github\.repository\s*==\s*'Code-My-Spec\/metric_flow'/,
           "ci.yml job is not guarded by github.repository == 'Code-My-Spec/metric_flow'"

    assert content =~ ~r/^\s*-?\s*run:\s*just ci\s*$/m,
           "ci.yml does not run `just ci`"
  end
end
