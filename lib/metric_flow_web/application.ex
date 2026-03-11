defmodule MetricFlowWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        MetricFlowWeb.Telemetry,
        MetricFlowWeb.PromEx,
        MetricFlow.Repo,
        {DNSCluster, query: Application.get_env(:metric_flow, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: MetricFlow.PubSub},
        MetricFlow.Vault,
        {Oban, Application.fetch_env!(:metric_flow, Oban)},
        {Cachex, name: :metric_cache},
        MetricFlow.Integrations.OAuthStateStore,
        # Start to serve requests, typically the last entry
        MetricFlowWeb.Endpoint
      ]
      |> dev_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MetricFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.env() == :dev do
    defp dev_children(children) do
      tunnel_config = Application.get_env(:metric_flow, :cloudflare_tunnel, [])

      tunnel_opts =
        Keyword.merge(tunnel_config,
          endpoint: MetricFlowWeb.Endpoint,
          otp_app: :metric_flow,
          origin_url: tunnel_config[:origin_url] || "http://127.0.0.1:#{System.get_env("PORT") || "4000"}"
        )

      children ++ [{ClientUtils.CloudflareTunnel, tunnel_opts}]
    end
  else
    defp dev_children(children), do: children
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MetricFlowWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
