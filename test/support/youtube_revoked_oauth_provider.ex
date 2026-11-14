defmodule MetricFlowTest.YouTubeRevokedOAuthProvider do
  @moduledoc "Synthetic Google token rejection after a user revokes access."
  alias MetricFlowTest.YouTubeOAuthProvider

  def config do
    YouTubeOAuthProvider.config()
    |> Keyword.put(:http_adapter, {Assent.HTTPAdapter.Req, [plug: &__MODULE__.respond/1]})
  end

  defdelegate strategy(), to: YouTubeOAuthProvider
  defdelegate normalize_user(user), to: YouTubeOAuthProvider

  def respond(%Plug.Conn{method: "POST", request_path: "/token"} = conn) do
    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(
      400,
      Jason.encode!(%{
        "error" => "invalid_grant",
        "error_description" => "Token has been expired or revoked."
      })
    )
  end

  def respond(conn), do: YouTubeOAuthProvider.respond(conn)
end
