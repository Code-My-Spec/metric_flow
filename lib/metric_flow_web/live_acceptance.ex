defmodule MetricFlowWeb.LiveAcceptance do
  @moduledoc """
  Lets a LiveView mounted over a real socket (CMS_E2E, phoenix_test_playwright)
  see the test's sandboxed data. Listed first in every `live_session`'s
  `on_mount`, ahead of hooks that query the repo.
  """
  import Phoenix.Component
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    socket =
      assign_new(socket, :phoenix_ecto_sandbox, fn ->
        if connected?(socket), do: get_connect_info(socket, :user_agent)
      end)

    Phoenix.Ecto.SQL.Sandbox.allow(socket.assigns.phoenix_ecto_sandbox, Ecto.Adapters.SQL.Sandbox)
    {:cont, socket}
  end
end
