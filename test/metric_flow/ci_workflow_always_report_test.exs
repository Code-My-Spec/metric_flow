defmodule MetricFlow.CiWorkflowAlwaysReportTest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../.github/workflows/ci.yml", __DIR__)

  test "ci-on-our-runner-deploys-uat: criterion 5 - when just ci fails the report step still runs (if: always())" do
    content = File.read!(@workflow)

    # The report step is the list item that contains the ci_report.sh run line.
    step =
      content
      |> String.split(~r/^      - /m)
      |> Enum.find(&(&1 =~ "ci_report.sh"))

    assert step, "ci.yml has no step running ci_report.sh"

    assert step =~ ~r/^\s*(?:if:\s*always\(\)|.*\n\s+if:\s*always\(\))/m or
             step =~ ~r/if:\s*\$\{\{\s*always\(\)\s*\}\}/,
           "report step is not marked to always run (if: always())"
  end
end
