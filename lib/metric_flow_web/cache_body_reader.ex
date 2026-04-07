defmodule MetricFlowWeb.CacheBodyReader do
  @moduledoc """
  Caches the raw request body in `conn.assigns[:raw_body]` before Plug.Parsers
  consumes it. Required for Stripe webhook signature verification, which needs
  the exact raw bytes to compute the HMAC.

  Only caches for the `/billing/webhooks` path to avoid memory overhead on
  other routes.
  """

  def read_body(%Plug.Conn{request_path: "/billing/webhooks"} = conn, opts) do
    case Plug.Conn.read_body(conn, opts) do
      {:ok, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:ok, body, conn}

      {:more, body, conn} ->
        conn = Plug.Conn.assign(conn, :raw_body, body)
        {:more, body, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def read_body(conn, opts) do
    Plug.Conn.read_body(conn, opts)
  end
end
