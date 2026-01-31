defmodule MetricFlowWeb.PageController do
  use MetricFlowWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
