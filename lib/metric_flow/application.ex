defmodule MetricFlow.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      MetricFlowWeb.Telemetry,
      MetricFlowWeb.PromEx,
      MetricFlow.Repo,
      {DNSCluster, query: Application.get_env(:metric_flow, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MetricFlow.PubSub},
      MetricFlow.Vault,
      {Oban, Application.fetch_env!(:metric_flow, Oban)},
      {Cachex, name: :metric_cache},
      # Start to serve requests, typically the last entry
      MetricFlowWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MetricFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MetricFlowWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
