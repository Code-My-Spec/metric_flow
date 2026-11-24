defmodule MetricFlow.CiWorkflowReportTest do
  use ExUnit.Case, async: true

  @workflow Path.expand("../../.github/workflows/ci.yml", __DIR__)

  test "ci-on-our-runner-deploys-uat: criterion 4 - after just ci the workflow runs ci_report.sh with CMS_SERVER, CMS_PROJECT_ID and CMS_DEPLOY_KEY" do
    content = File.read!(@workflow)

    {ci_index, _} = :binary.match(content, "run: just ci")

    report =
      Regex.run(~r/run:\s*"?\$CODEMYSPEC_PLUGIN\/bin\/ci_report\.sh"?/, content, return: :index)

    assert report, "ci.yml does not run $CODEMYSPEC_PLUGIN/bin/ci_report.sh"

    [{report_index, _}] = report
    assert report_index > ci_index, "ci_report.sh must run after `just ci`"

    report_section = binary_part(content, report_index, byte_size(content) - report_index)

    assert report_section =~ ~r/CMS_SERVER:\s*https:\/\/codemyspec\.com\s*$/m,
           "report step must set CMS_SERVER to https://codemyspec.com"

    assert report_section =~ ~r/CMS_PROJECT_ID:\s*\$\{\{\s*vars\.CMS_PROJECT_ID\s*\}\}/,
           "report step must set CMS_PROJECT_ID from vars.CMS_PROJECT_ID"

    assert report_section =~ ~r/CMS_DEPLOY_KEY:\s*\$\{\{\s*secrets\.CMS_DEPLOY_KEY\s*\}\}/,
           "report step must set CMS_DEPLOY_KEY from secrets.CMS_DEPLOY_KEY"
  end
end
