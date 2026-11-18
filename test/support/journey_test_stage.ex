defmodule MetricFlowTest.JourneyTestStage do
  @moduledoc """
  Wraps one stage of a journey walk so a failure inside it names the
  stage, shared by this journey's LiveView and Playwright drivers so
  neither can drift from the other's stage names. The demo recorder
  (CodeMySpec.Journeys.DemoWalk) routes on the exact failure text this
  produces: `Journey stage "<name>" failed`.
  """

  @doc """
  Runs `fun.(session)` for stage `name` and returns its result -- typically
  the same session, piped stage to stage. An exception raised inside `fun`
  is re-raised with the stage name prefixed onto its message, in the exact
  form the recorder matches, rather than a bare assertion failure with no
  indication of which stage broke.
  """
  def stage(session, name, fun) do
    fun.(session)
  rescue
    error in [ExUnit.AssertionError] ->
      reraise %{error | message: "Journey stage \"#{name}\" failed: #{error.message}"},
              __STACKTRACE__

    error ->
      reraise "Journey stage \"#{name}\" failed: #{Exception.message(error)}", __STACKTRACE__
  end
end
