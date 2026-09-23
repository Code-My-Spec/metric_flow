defmodule MetricFlowSpex do
  @moduledoc """
  Top-level boundary for BDD spex modules.

  Spex drive the application the way a user does — over HTTP or through
  LiveView — so they may reach the web layer, and reach application state only
  through `MetricFlowSpex.Fixtures`, which is its own boundary for that reason.

  `MetricFlow` is here because `MetricFlowSpex.Case` owns its sandbox and so
  names `MetricFlow.Repo` (an export of that boundary). `MetricFlowTest` is
  here because the 374 spex already written open with
  `use MetricFlowTest.ConnCase`; new ones should use `MetricFlowSpex.Case`, and
  this dep can go once none are left.

  Nothing enforces any of this yet: `:boundary` is not in `compilers(:test)`
  and there is no `spex:` project key, so these declarations are intent rather
  than a gate. Turning the compiler on is a separate, deliberate step — it
  converts every existing violation into a compile error at once.
  """
  use Boundary,
    top_level?: true,
    deps: [MetricFlow, MetricFlowWeb, MetricFlowTest, MetricFlowSpex.Fixtures]
end
