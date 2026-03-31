defmodule MetricFlowWeb.Hooks.CodemyspecFeedbackHook do
  @moduledoc """
  LiveView on_mount hook that checks CodeMySpec connection status.

  Assigns `:codemyspec_connected` to the socket, which controls whether
  the feedback widget renders.
  """

  import Phoenix.Component, only: [assign: 3]

  alias MetricFlow.Integrations

  def on_mount(:default, _params, _session, socket) do
    case socket.assigns[:current_scope] do
      nil ->
        {:cont, assign(socket, :codemyspec_connected, false)}

      scope ->
        connected = Integrations.connected?(scope, :codemyspec)
        {:cont, assign(socket, :codemyspec_connected, connected)}
    end
  end
end
