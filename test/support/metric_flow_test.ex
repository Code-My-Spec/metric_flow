defmodule MetricFlowTest do
  @moduledoc """
  Boundary for test support modules.

  This boundary has checks disabled so test support code can
  freely access any module without boundary violations.
  """

  use Boundary, check: [in: false, out: false]
end
