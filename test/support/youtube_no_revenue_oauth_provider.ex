defmodule MetricFlowTest.YouTubeNoRevenueOAuthProvider do
  @moduledoc """
  Synthetic Google token response for a user declining revenue permission.
  The authorization request still asks for revenue, but the returned token
  grants only channel and non-monetary analytics read access.
  """

  alias MetricFlowTest.YouTubeOAuthProvider

  def config do
    YouTubeOAuthProvider.config()
    |> Keyword.put(:http_adapter, {Assent.HTTPAdapter.Req, [plug: &__MODULE__.respond/1]})
  end

  defdelegate strategy(), to: YouTubeOAuthProvider
  defdelegate normalize_user(user), to: YouTubeOAuthProvider

  def respond(%Plug.Conn{method: "POST", request_path: "/token"} = conn) do
    body = %{
      "access_token" => "synthetic-youtube-no-revenue-access",
      "refresh_token" => "synthetic-youtube-no-revenue-refresh",
      "expires_in" => 3600,
      "token_type" => "Bearer",
      "scope" =>
        Enum.join(
          [
            "email",
            "profile",
            "https://www.googleapis.com/auth/youtube.readonly",
            "https://www.googleapis.com/auth/yt-analytics.readonly"
          ],
          " "
        )
    }

    conn
    |> Plug.Conn.put_resp_content_type("application/json")
    |> Plug.Conn.send_resp(200, Jason.encode!(body))
  end

  def respond(conn), do: YouTubeOAuthProvider.respond(conn)
end
