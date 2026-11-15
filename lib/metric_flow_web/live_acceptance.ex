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

    # `allow/2` turns on trap_exit for this LiveView process (only under a real
    # socket, i.e. only here), so a Task.async it started completing normally
    # now arrives as {:EXIT, pid, :normal} instead of being invisible. No
    # LiveView's own handle_info/2 expects that message; swallow only the
    # normal case so an abnormal exit still surfaces.
    socket =
      attach_hook(socket, :sandbox_exits, :handle_info, fn
        {:EXIT, _pid, :normal}, s -> {:halt, s}
        _msg, s -> {:cont, s}
      end)

    {:cont, socket}
  end
end
