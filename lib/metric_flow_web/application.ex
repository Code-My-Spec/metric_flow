defmodule MetricFlowWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  alias MetricFlow.Ai.VegaSpecValidator

  @impl true
  def start(_type, _args) do
    children =
      [
        MetricFlowWeb.Telemetry,
        MetricFlow.Repo,
        {DNSCluster, query: Application.get_env(:metric_flow, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: MetricFlow.PubSub},
        MetricFlow.Vault,
        {Oban, Application.fetch_env!(:metric_flow, Oban)},
        {Cachex, name: :metric_cache},
        MetricFlow.Integrations.OAuthStateStore,
        # Start to serve requests, typically the last entry
        MetricFlowWeb.Endpoint,
        # CodeMySpec preview tunnel. Distinct :id and :name from the legacy
        # dev.metric-flow.app tunnel below — both can be enabled at once in
        # dev, and a shared default name would crash the second GenServer to
        # register. Safe to always include: ClientUtils.CloudflareTunnel
        # ignores itself (via :enabled) when this checkout has no preview, or
        # when this boot is a non-main copy — see `main_copy?/0`.
        Supervisor.child_spec({ClientUtils.CloudflareTunnel, preview_tunnel(:metric_flow)},
          id: :preview_tunnel
        )
      ]
      |> dev_children()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    # Compile and cache the Vega-Lite JSON schema for spec validation
    VegaSpecValidator.init()

    opts = [strategy: :one_for_one, name: MetricFlow.Supervisor]
    Supervisor.start_link(children, opts)
  end

  if Mix.env() == :dev do
    defp dev_children(children) do
      tunnel_config = Application.get_env(:metric_flow, :cloudflare_tunnel, [])

      if tunnel_config[:enabled] and main_copy?() do
        tunnel_opts =
          Keyword.merge(tunnel_config,
            endpoint: MetricFlowWeb.Endpoint,
            otp_app: :metric_flow,
            origin_url:
              tunnel_config[:origin_url] || "http://127.0.0.1:#{System.get_env("PORT") || "4000"}"
          )

        children ++ [{ClientUtils.CloudflareTunnel, tunnel_opts}]
      else
        children
      end
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

  defp preview_tunnel(otp_app) do
    config = Application.get_env(otp_app, :preview, [])

    [
      enabled: config[:tunnel_id] not in [nil, ""] and main_copy?(),
      mode: :named,
      hostname: config[:hostname],
      tunnel_id: config[:tunnel_id],
      account_tag: config[:account_tag],
      tunnel_secret: config[:tunnel_secret],
      origin_url: config[:origin_url],
      endpoint: MetricFlowWeb.Endpoint,
      otp_app: otp_app,
      # Distinct from the legacy tunnel's default (module) name — both can be
      # registered at once, and GenServer.start_link/3 refuses a second
      # process under a name already taken.
      name: MetricFlowWeb.PreviewTunnel,
      # Distinct from the legacy tunnel's default tmp/cloudflared/ — both
      # tunnels writing config.yml/credentials.json to the same directory
      # meant whichever wrote last silently won, so both cloudflared
      # processes ran the same (legacy) tunnel.
      base_dir: Path.join(File.cwd!(), "tmp/cloudflared/preview")
    ]
  end

  # Both tunnels above read a hardcoded hostname/tunnel id/account tag from
  # config, unconditionally, on every :dev boot — main's own. A non-main
  # working copy booting the same way (`CmsHarness.AppInstance`, CodeMySpec
  # story 1108) started them too, running a second `cloudflared` per tunnel
  # answering for main's tunnel from a different port. Harmless only because
  # every copy's config named the same origin main's did; a live risk the
  # moment one didn't (Cloudflare splitting main's public traffic between the
  # two apps). `CMS_MAIN_COPY` is set by the harness's own
  # `AppInstance.Runner.Local.launch/6` for exactly this reason; unset (a
  # developer's own `mix phx.server`, not going through the harness at all)
  # reads as main, matching every boot before this existed.
  defp main_copy?, do: System.get_env("CMS_MAIN_COPY") != "false"
end
