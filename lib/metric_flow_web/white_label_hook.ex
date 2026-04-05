defmodule MetricFlowWeb.WhiteLabelHook do
  @moduledoc """
  LiveView on_mount hook that loads white-label configuration.

  Reads the subdomain-based white-label config from the session (set by the
  WhiteLabel plug). On the main domain (no subdomain), no white-label config
  is applied, ensuring clients see default branding.
  """

  import Phoenix.Component, only: [assign: 3]

  @spec on_mount(:load_white_label, map(), map(), Phoenix.LiveView.Socket.t()) ::
          {:cont, Phoenix.LiveView.Socket.t()}
  def on_mount(:load_white_label, _params, session, socket) do
    config = Map.get(session, "white_label_config")
    {:cont, assign(socket, :white_label_config, config)}
  end
end
