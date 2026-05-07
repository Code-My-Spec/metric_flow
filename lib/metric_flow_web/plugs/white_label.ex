defmodule MetricFlowWeb.Plugs.WhiteLabel do
  @moduledoc """
  Plug that detects agency subdomains or custom domains and loads white-label
  configuration.

  Resolution order:
  1. If the host is NOT a metric-flow.app domain, attempt a custom domain lookup
     (only returns verified domains).
  2. Otherwise, extract the subdomain segment and look up by subdomain.

  Stores the branding data in the session so that the LiveView on_mount hook
  can assign it to the socket.
  """

  import Plug.Conn

  alias MetricFlow.Agencies

  @behaviour Plug

  @app_domain "metric-flow.app"

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    config = lookup_by_custom_domain(conn.host) || lookup_by_subdomain(conn.host)

    case config do
      nil ->
        put_session(conn, :white_label_config, nil)

      config ->
        put_session(conn, :white_label_config, %{
          subdomain: config.subdomain,
          custom_domain: config.custom_domain,
          logo_url: config.logo_url,
          primary_color: config.primary_color,
          secondary_color: config.secondary_color
        })
    end
  end

  defp lookup_by_custom_domain(host) do
    if String.ends_with?(host, "." <> @app_domain) or host == @app_domain do
      nil
    else
      Agencies.get_white_label_config_by_custom_domain(host)
    end
  end

  defp lookup_by_subdomain(host) do
    case extract_subdomain(host) do
      nil -> nil
      subdomain -> Agencies.get_white_label_config_by_subdomain(subdomain)
    end
  end

  defp extract_subdomain(host) when is_binary(host) do
    parts = String.split(host, ".")

    case parts do
      [subdomain | _rest] when length(parts) >= 3 -> subdomain
      _ -> nil
    end
  end

  defp extract_subdomain(_), do: nil
end
