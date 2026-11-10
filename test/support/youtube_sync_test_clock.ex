defmodule MetricFlowTest.YouTubeSyncTestClock do
  @moduledoc """
  Controlled time boundary for YouTube incremental-sync acceptance specs.
  The sync implementation must use the configured :sync_clock module for
  its current date. This fixture never creates or modifies persisted data.
  Specs using this application configuration must run synchronously.
  """

  use Agent

  def start_link(%DateTime{} = now) do
    Agent.start_link(fn -> now end, name: __MODULE__)
  end

  def utc_now, do: Agent.get(__MODULE__, & &1)
  def utc_today, do: utc_now() |> DateTime.to_date()

  def advance_day do
    Agent.update(__MODULE__, &DateTime.add(&1, 86_400, :second))
  end
end
