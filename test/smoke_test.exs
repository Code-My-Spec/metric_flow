defmodule MetricFlow.SmokeTest do
  @moduledoc """
  Verifies that all decided libraries load and basic functionality works.
  """
  use MetricFlowTest.DataCase, async: true

  describe "decided libraries load correctly" do
    test "Oban is configured" do
      config = Application.fetch_env!(:metric_flow, Oban)
      assert config[:testing] == :manual
      assert :sync in Keyword.keys(config[:queues] || [])
    end

    test "Cachex metric_cache is running" do
      assert {:ok, true} = Cachex.put(:metric_cache, :smoke_test, "works")
      assert {:ok, "works"} = Cachex.get(:metric_cache, :smoke_test)
      Cachex.del(:metric_cache, :smoke_test)
    end

    test "Cloak Vault is running" do
      assert Process.whereis(MetricFlow.Vault) != nil
    end

    test "VegaLite can build a spec" do
      spec =
        VegaLite.new()
        |> VegaLite.data_from_values([%{x: 1, y: 2}])
        |> VegaLite.mark(:point)
        |> VegaLite.encode_field(:x, "x", type: :quantitative)
        |> VegaLite.encode_field(:y, "y", type: :quantitative)
        |> VegaLite.to_spec()

      assert is_map(spec)
      assert spec["mark"] == "point"
    end

    # Was Sentry and `MetricFlowWeb.PromEx`. The appsignal_observability_hetzner
    # ADR supersedes the 2026-02-21 Sentry+PromEx ADR after the move off Fly.io
    # — neither is a dependency any more and `prom_ex.ex` does not exist, so
    # both assertions were pinning a decision that had been reversed.
    test "AppSignal is configured" do
      assert Code.ensure_loaded?(Appsignal)
      assert Code.ensure_loaded?(Appsignal.Phoenix)
      # Off in test so a suite run reports nothing; the point is that it loads.
      assert Application.fetch_env!(:appsignal, :config)[:active] == false
    end

    test "ExAws is configured" do
      assert Code.ensure_loaded?(ExAws)
      assert Code.ensure_loaded?(ExAws.S3)
    end

    test "Assent OAuth strategies are available" do
      assert Code.ensure_loaded?(Assent.Strategy.Google)
      assert Code.ensure_loaded?(Assent.Strategy.Github)
    end

    test "ReqLLM is available" do
      assert Code.ensure_loaded?(ReqLLM)
    end

    test "Swoosh mailer is configured" do
      assert Code.ensure_loaded?(MetricFlow.Mailer)
    end
  end
end
