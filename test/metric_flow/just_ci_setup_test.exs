defmodule MetricFlow.JustCiSetupTest do
  use ExUnit.Case, async: true

  @justfile Path.expand("../../justfile", __DIR__)

  test "ci-on-our-runner-deploys-uat: criterion 6 - just ci runs ci-setup then certifies, and ci-setup prepares a clean Linux runner" do
    content = File.read!(@justfile)

    assert content =~ ~r/^ci: ci-setup\b.*\(certify "[^"]+"\)\s*$/m,
           "justfile `ci` recipe must run ci-setup and then certify"

    [_, after_header] = String.split(content, ~r/^ci-setup:\s*$/m, parts: 2)

    # The recipe body is the indented block that follows the header.
    body =
      after_header
      |> String.split("\n")
      |> Enum.drop_while(&(&1 == ""))
      |> Enum.take_while(&(&1 == "" or String.starts_with?(&1, [" ", "\t"])))
      |> Enum.join("\n")

    assert body =~ ~r/mix deps\.get/, "ci-setup must install the test deps"
    assert body =~ ~r/npm ci/, "ci-setup must install the npm packages"
    assert body =~ ~r/mix assets\.build/, "ci-setup must build the test assets"
  end
end
