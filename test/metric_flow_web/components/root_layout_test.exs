defmodule MetricFlowWeb.RootLayoutTest do
  @moduledoc """
  The Anderson BI design system is one fixed dark theme. The root layout
  must hard-set `data-theme="dark"` on <html> and must not load the old
  OS-aware theme.js that could switch it out. See DESIGN.md.
  """
  use MetricFlowTest.ConnCase, async: true

  test "GET / carries data-theme=\"dark\" on <html> and no theme toggle", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s(<html lang="en" data-theme="dark">),
           "Expected <html data-theme=\"dark\">, got head: #{String.slice(html, 0, 400)}"

    refute html =~ "/assets/js/theme.js",
           "theme.js is the OS-aware light/dark switch that DESIGN.md forbids"

    refute html =~ "data-phx-theme",
           "the theme toggle buttons that read data-phx-theme are forbidden"

    refute html =~ "prefers-color-scheme",
           "the dark theme must not depend on prefers-color-scheme"
  end
end
