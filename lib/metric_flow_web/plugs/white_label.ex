defmodule MetricFlowWeb.Plugs.WhiteLabel do
  @moduledoc """
  Plug that detects agency subdomains and loads white-label configuration.

  Extracts the first subdomain segment from the request host, looks up the
  matching WhiteLabelConfig, and stores the branding data in the session
  so that the LiveView on_mount hook can assign it to the socket.
  """

  import Plug.Conn

  alias MetricFlow.Agencies

  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case extract_subdomain(conn.host) do
      nil ->
        put_session(conn, :white_label_config, nil)

      subdomain ->
        case Agencies.get_white_label_config_by_subdomain(subdomain) do
          nil ->
            put_session(conn, :white_label_config, nil)

          config ->
            put_session(conn, :white_label_config, %{
              subdomain: config.subdomain,
              logo_url: config.logo_url,
              primary_color: config.primary_color,
              secondary_color: config.secondary_color
            })
        end
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
