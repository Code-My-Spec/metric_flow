defmodule MetricFlowTest.DnsStub do
  @moduledoc """
  Test stub for DNS lookups. Replaces `MetricFlow.Agencies.DnsClient`
  during tests.

  ## Usage

      setup do
        MetricFlowTest.DnsStub.setup_dns_stub(%{
          "acme.metric-flow.app" => ["app.metricflow.io"],
          "analytics.example.com" => ["app.metricflow.io"],
          "bad.example.com" => ["other-server.example.com"]
        })
      end

  Hostnames not in the map return an empty list (no CNAME).
  """

  @behaviour MetricFlow.Agencies.DnsClient

  @doc """
  Configures the DNS stub with a map of hostname => [cname_targets].

  Sets the `:dns_client` app env and registers an `on_exit` callback
  to restore the original value.
  """
  def setup_dns_stub(cname_map \\ %{}) do
    original = Application.get_env(:metric_flow, :dns_client)
    Application.put_env(:metric_flow, :dns_client, __MODULE__)
    Application.put_env(:metric_flow, :dns_stub_responses, cname_map)

    ExUnit.Callbacks.on_exit(fn ->
      if original do
        Application.put_env(:metric_flow, :dns_client, original)
      else
        Application.delete_env(:metric_flow, :dns_client)
      end

      Application.delete_env(:metric_flow, :dns_stub_responses)
    end)

    :ok
  end

  @impl true
  def lookup_cname(hostname) do
    responses = Application.get_env(:metric_flow, :dns_stub_responses, %{})
    Map.get(responses, hostname, [])
  end
end
