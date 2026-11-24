defmodule MetricFlow.LandingFastForwardTest do
  use ExUnit.Case, async: true

  @origin_commits ~w(
    c8526c95
    626c45c9
    d3590559
    3f99ba24
    9e935cb9
    4706fb7b
    7a0e9a4c
  )

  defp ancestor?(ancestor, descendant) do
    {_out, status} =
      System.cmd("git", ["merge-base", "--is-ancestor", ancestor, descendant],
        stderr_to_stdout: true
      )

    status == 0
  end

  test "ci-on-our-runner-deploys-uat: criterion 1 - main contains origin/main unchanged, so a landing is a fast-forward" do
    for sha <- @origin_commits do
      assert ancestor?(sha, "main"),
             "origin/main commit #{sha} is not an ancestor of main (content changed or missing)"
    end

    assert ancestor?("origin/main", "main"),
           "origin/main is not an ancestor of main, so pushing main to origin would not be a fast-forward"
  end
end
