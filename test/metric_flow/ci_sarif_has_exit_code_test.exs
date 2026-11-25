defmodule MetricFlow.CiSarifHasExitCodeTest do
  # The CodeMySpec server rejects SARIF that lacks invocations[0].exitCode, so
  # every evidence file `mix client_utils.sarif` writes (one per step of
  # `just ci`) must include it. Prior to client_utils 4e275d9 the task emitted
  # a run with only `tool` and `results`, so the CI report upload failed.
  use ExUnit.Case, async: true

  @tag :tmp_dir
  test "ci-sarif-has-exit-code: mix client_utils.sarif records invocations[0].exitCode",
       %{tmp_dir: tmp_dir} do
    output = Path.join(tmp_dir, "exit_code.sarif")
    project_root = Path.expand("../..", __DIR__)

    {_text, 0} =
      System.cmd("mix", ["client_utils.sarif", output, "--", "true"],
        cd: project_root,
        stderr_to_stdout: true,
        env: [{"MIX_ENV", "test"}]
      )

    %{"runs" => [run | _]} = output |> File.read!() |> Jason.decode!()

    assert [invocation | _] = run["invocations"],
           "SARIF run must include invocations (bump client_utils to 4e275d9 or later)"

    assert invocation["exitCode"] == 0,
           "invocation must include exitCode (bump client_utils to 4e275d9 or later)"
  end
end
