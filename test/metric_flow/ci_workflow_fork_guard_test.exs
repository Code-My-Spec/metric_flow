defmodule MetricFlow.CiWorkflowForkGuardTest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../.github/workflows/ci.yml", __DIR__)
  @repo "Code-My-Spec/metric_flow"

  # Evaluates the simple `github.repository == '<repo>'` guard for a given repository.
  defp guard_value(expr, repository) do
    case Regex.run(~r/^\s*github\.repository\s*==\s*'([^']+)'\s*$/, expr) do
      [_, expected] -> expected == repository
      nil -> flunk("guard is not a plain github.repository equality: #{inspect(expr)}")
    end
  end

  test "ci-on-our-runner-deploys-uat: criterion 3 - in any other repository the job guard is false" do
    content = File.read!(@workflow)

    [_, jobs] = String.split(content, ~r/^jobs:\s*$/m, parts: 2)

    guards =
      Regex.scan(~r/^    if:\s*(.+?)\s*$/m, jobs, capture: :all_but_first)
      |> List.flatten()

    assert guards != [], "ci.yml job has no job-level `if:` guard"

    job_names = Regex.scan(~r/^  ([A-Za-z0-9_-]+):\s*$/m, jobs, capture: :all_but_first)

    assert length(guards) == length(job_names),
           "every job in ci.yml must carry the repository guard"

    for guard <- guards do
      assert guard_value(guard, @repo), "guard is false in #{@repo} itself"

      for other <- [
            "someone-else/metric_flow",
            "Code-My-Spec/metric_flow_fork",
            "Code-My-Spec/other"
          ] do
        refute guard_value(guard, other), "guard is true in #{other}, so CI would run there"
      end
    end
  end
end
