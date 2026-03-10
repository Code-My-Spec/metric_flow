defmodule MetricFlowWeb.PageController do
  use MetricFlowWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end

  def terms(conn, _params) do
    render(conn, :terms)
  end
end
