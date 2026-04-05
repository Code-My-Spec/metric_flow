defmodule MetricFlowWeb.WhiteLabelHookTest do
  use MetricFlowTest.ConnCase, async: true

  alias MetricFlowWeb.WhiteLabelHook

  # ---------------------------------------------------------------------------
  # on_mount/4
  # ---------------------------------------------------------------------------

  describe "on_mount/4" do
    test "assigns white_label_config from session when present" do
      config = %{
        subdomain: "acme",
        logo_url: "https://acme.com/logo.png",
        primary_color: "#FF0000",
        secondary_color: "#00FF00"
      }

      session = %{"white_label_config" => config}
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

      {:cont, socket} = WhiteLabelHook.on_mount(:load_white_label, %{}, session, socket)

      assert socket.assigns.white_label_config == config
    end

    test "assigns nil when no white_label_config in session" do
      session = %{}
      socket = %Phoenix.LiveView.Socket{assigns: %{__changed__: %{}}}

      {:cont, socket} = WhiteLabelHook.on_mount(:load_white_label, %{}, session, socket)

      assert socket.assigns.white_label_config == nil
    end
  end
end
