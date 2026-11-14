defmodule MetricFlowWeb.UserLive.AndersonBiRebrandTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest

  @moduledoc """
  Reproduces issue 3c7037ee: the customer-facing product is still branded
  MetricFlow (page title, login heading, "New to MetricFlow?") instead of
  the approved rename to Anderson BI.
  """

  test "the public login page is branded Anderson BI, not MetricFlow", %{conn: conn} do
    {:ok, _view, html} = live(conn, ~p"/users/log-in")

    assert html =~ "Anderson BI"
    refute html =~ "MetricFlow"
  end
end
