defmodule MetricFlow.CiEvidenceInReportDirTest do
  # ci_report.sh uploads .code_my_spec/evidence/*.sarif (flat, no recurse);
  # `just ci` must write SARIF there and must wipe last run's files first,
  # and those generated files must not be committed.
  use ExUnit.Case, async: true

  @justfile Path.expand("../../justfile", __DIR__)
  @gitignore Path.expand("../../.gitignore", __DIR__)

  test "ci-evidence-where-the-report-reads: criterion 1 - just ci writes SARIF flat into .code_my_spec/evidence/ and clears older files first" do
    content = File.read!(@justfile)

    assert content =~
             ~r/^ci:\s+ci-setup\b[^\n]*\(certify "\.code_my_spec\/evidence"\)\s*$/m,
           "`ci` recipe must certify into .code_my_spec/evidence (where ci_report.sh reads from)"

    refute content =~ ~r/\(certify "ci"\)/,
           "`ci` recipe must not write evidence under ./ci/ anymore"

    assert content =~ ~r/rm\s+-f\s+\.code_my_spec\/evidence\/\*\.sarif/,
           "`ci` must clear stale .code_my_spec/evidence/*.sarif before a run"

    # certify writes `{{dir}}/<name>.sarif` — flat, no subdirectories.
    assert content =~
             ~r/certify dir:[^\n]*\n(?:[ \t][^\n]*\n)*[ \t]+env MIX_ENV=test mix client_utils\.sarif "\{\{dir\}\}\/[^\/"]+\.sarif"/,
           "certify must write SARIF files directly under its `dir` (no subdirectories)"
  end

  test "ci-evidence-where-the-report-reads: criterion 2 - generated SARIF under .code_my_spec/evidence/ is gitignored" do
    content = File.read!(@gitignore)

    assert content =~ ~r/^\/?\.code_my_spec\/evidence\/\*\.sarif\s*$/m,
           ".gitignore must ignore .code_my_spec/evidence/*.sarif so CI outputs are not committed"
  end
end
