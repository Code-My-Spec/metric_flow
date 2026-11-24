defmodule MetricFlow.NoGitStateReadsInTestsTest do
  use ExUnit.Case, async: true

  @test_dir Path.expand("../..", __DIR__) |> Path.join("test")

  @patterns [
    ~r/System\.cmd\s*\(\s*["']git["']/,
    ~r/["']git\s+(?:log|merge-base|rev-parse|rev-list|cat-file|show|diff|ls-remote|for-each-ref|fetch|pull|push)/,
    ~r/["']origin\/[^"'\s]+["']/
  ]

  test "no test file invokes git or references origin refs" do
    offenders =
      @test_dir
      |> Path.join("**/*.exs")
      |> Path.wildcard()
      |> Enum.flat_map(fn file ->
        content = File.read!(file)

        @patterns
        |> Enum.filter(&Regex.match?(&1, content))
        |> Enum.map(fn pattern -> {file, pattern.source} end)
      end)

    assert offenders == [],
           "these test files invoke git or reference origin refs " <>
             "(the suite must not depend on the checkout's git state):\n  " <>
             Enum.map_join(offenders, "\n  ", fn {f, p} -> "#{f} matches /#{p}/" end)
  end
end
