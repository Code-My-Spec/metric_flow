defmodule MetricFlowTest.HermeticHttp do
  @moduledoc """
  Keeps tests off the network. Any Req request that doesn't bring its own `:plug`
  (cassette, `Req.Test`, injected stub) is answered with a Google-style 401.

  Specs drive real syncs with fake tokens and expect the provider to reject them;
  offline that used to surface as logged transport errors (`non-existing domain`).
  """

  def install do
    Req.default_options(plug: &unauthenticated/1)
  end

  def unauthenticated(conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(
      401,
      ~s({"error":{"code":401,"message":"stubbed: no network in tests","status":"UNAUTHENTICATED"}})
    )
  end
end
