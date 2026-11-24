defmodule MetricFlow.TestEnvPlaceholderFallbackTest do
  use ExUnit.Case, async: true

  @justfile Path.expand("../../justfile", __DIR__)

  test "ci-runs-without-the-age-key: test-env still decrypts when a key is available, and falls back to placeholder values when no sops/age key is present" do
    content = File.read!(@justfile)

    [_, after_header] = String.split(content, ~r/^test-env:\s*$/m, parts: 2)

    body =
      after_header
      |> String.split("\n")
      |> Enum.drop_while(&(&1 == ""))
      |> Enum.take_while(&(&1 == "" or String.starts_with?(&1, [" ", "\t"])))
      |> Enum.join("\n")

    assert body =~ ~r/sops -d .* envs\/test\.enc\.env/,
           "test-env must still try to decrypt envs/test.enc.env with sops when an age key is available"

    assert body =~ ~r/placeholder/i,
           "test-env must write a placeholder .env.test when sops cannot decrypt (CI box has no age key)"
  end
end
