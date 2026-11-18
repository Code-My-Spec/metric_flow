defmodule MetricFlowWeb.Plugs.MCPAuth do
  @moduledoc """
  OAuth bearer-token auth for `/mcp`. A valid, unexpired access token issued
  by `MetricFlow.Oauth` assigns `:mcp_user_id` (the token's resource owner),
  which the MCP server reads to act as that user. Anything else gets a 401
  whose `WWW-Authenticate` header points the client at the protected-resource
  metadata, so an MCP client can discover the authorization server and sign
  the user in (MCP authorization spec, RFC 9728 §5.1).
  """
  @behaviour Plug

  import Plug.Conn

  alias MetricFlow.Oauth

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token | _] ->
        case Oauth.verify_access_token(String.trim(token)) do
          {:ok, user_id} ->
            assign(conn, :mcp_user_id, user_id)

          {:error, :invalid} ->
            unauthorized(conn, "invalid_token", "The access token is invalid or expired")
        end

      _ ->
        unauthorized(conn, "invalid_request", "Missing bearer token")
    end
  end

  defp unauthorized(conn, error, description) do
    base_url = MetricFlowWeb.Endpoint.url()
    metadata = base_url <> "/.well-known/oauth-protected-resource" <> conn.request_path

    conn
    |> put_resp_header(
      "www-authenticate",
      ~s(Bearer realm="#{base_url <> conn.request_path}", error="#{error}", ) <>
        ~s(error_description="#{description}", resource_metadata="#{metadata}")
    )
    |> put_resp_content_type("application/json")
    |> send_resp(401, Jason.encode!(%{error: error, error_description: description}))
    |> halt()
  end
end
