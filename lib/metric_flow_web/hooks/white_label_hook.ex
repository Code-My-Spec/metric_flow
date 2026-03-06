defmodule MetricFlowWeb.WhiteLabelHook do
  @moduledoc """
  LiveView on_mount hook that loads white-label configuration from the session.

  Reads the white-label config stored by `MetricFlowWeb.Plugs.WhiteLabel`
  and assigns it to the socket so the layout can render agency branding.
  """

  import Phoenix.Component, only: [assign: 3]

  def on_mount(:load_white_label, _params, session, socket) do
    config = Map.get(session, "white_label_config")
    {:cont, assign(socket, :white_label_config, config)}
  end
end
