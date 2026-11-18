defmodule MetricFlowWeb.OAuthController do
  @moduledoc """
  OAuth 2.1 authorization server endpoints for MCP clients: authorization
  (consent), token, revocation, Dynamic Client Registration (RFC 7591) and
  the discovery documents (RFC 8414, RFC 9728). PKCE S256 is required; see
  `MetricFlow.Oauth`.
  """

  use MetricFlowWeb, :controller

  require Logger

  alias MetricFlow.Oauth

  @forwarded_params ~w(client_id redirect_uri scope response_type state code_challenge code_challenge_method)

  @doc "GET /oauth/authorize — consent page (bounces through login first)."
  def authorize(conn, params) do
    with :ok <- check_pkce(conn, params) do
      case conn.assigns[:current_scope] do
        %{user: %{} = user} ->
          user
          |> Oauth.preauthorize(params)
          |> Oauth.attach_code_challenge(params)
          |> handle_preauthorize(conn, params)

        _ ->
          conn
          |> put_session(:user_return_to, "/oauth/authorize?" <> URI.encode_query(params))
          |> redirect(to: ~p"/users/log-in")
      end
    end
  end

  defp handle_preauthorize({:ok, client, scopes}, conn, params),
    do: render(conn, :authorize, client: client, scopes: scopes, params: params)

  defp handle_preauthorize({:redirect, uri}, conn, _params), do: redirect(conn, external: uri)
  defp handle_preauthorize({:native_redirect, payload}, conn, _params), do: json(conn, payload)

  defp handle_preauthorize({:error, error, status}, conn, _params) do
    Logger.info("OAuth preauthorize refused: #{inspect(error)}")

    conn
    |> put_status(status)
    |> render(:error, error: error)
  end

  @doc "POST /oauth/authorize — the user approved."
  def create(conn, params) do
    with :ok <- check_pkce(conn, params),
         {:ok, user} <- require_user(conn) do
      case user |> Oauth.authorize(params) |> Oauth.attach_code_challenge(params) do
        {:redirect, uri} -> redirect(conn, external: uri)
        {:native_redirect, payload} -> json(conn, payload)
        {:error, error, status} -> conn |> put_status(status) |> render(:error, error: error)
      end
    end
  end

  @doc "DELETE /oauth/authorize — the user denied."
  def delete(conn, params) do
    with {:ok, user} <- require_user(conn) do
      case Oauth.deny(user, params) do
        {:redirect, uri} -> redirect(conn, external: uri)
        {:error, error, status} -> conn |> put_status(status) |> render(:error, error: error)
      end
    end
  end

  defp require_user(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{} = user} ->
        {:ok, user}

      _ ->
        conn
        |> put_flash(:error, "You must log in to continue.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp check_pkce(conn, params) do
    case Oauth.validate_code_challenge(params) do
      :ok ->
        :ok

      {:error, description} ->
        conn
        |> put_status(:bad_request)
        |> render(:error, error: %{error: :invalid_request, error_description: description})
    end
  end

  @doc "Hidden fields the consent form posts back."
  def forwarded_params, do: @forwarded_params

  @doc "POST /oauth/token — authorization_code (with PKCE) and refresh_token."
  def token(conn, params) do
    case Oauth.grant_token(with_basic_client(conn, params)) do
      {:ok, token} ->
        conn
        |> put_resp_header("cache-control", "no-store")
        |> json(%{
          access_token: token.access_token,
          refresh_token: token.refresh_token,
          expires_in: token.expires_in,
          token_type: "Bearer",
          scope: token.scope
        })

      {:error, error, status} ->
        oauth_error(conn, error, status)
    end
  end

  # client_secret_basic (RFC 6749 §2.3.1): ChatGPT and other DCR clients send
  # the credentials in the Authorization header; the library reads the body.
  defp with_basic_client(conn, params) do
    with ["Basic " <> encoded] <- get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(String.trim(encoded)),
         [id, secret] <- String.split(decoded, ":", parts: 2),
         id = URI.decode_www_form(id),
         true <- params["client_id"] in [nil, id] do
      params
      |> Map.put("client_id", id)
      |> Map.put("client_secret", URI.decode_www_form(secret))
    else
      _ -> params
    end
  end

  @doc "POST /oauth/revoke (RFC 7009)."
  def revoke(conn, params) do
    case Oauth.revoke_token(with_basic_client(conn, params)) do
      {:ok, _} -> json(conn, %{})
      {:error, error, status} -> oauth_error(conn, error, status)
    end
  end

  defp oauth_error(conn, %{error: error, error_description: description}, status) do
    conn
    |> put_status(status)
    |> json(%{error: to_string(error), error_description: description})
  end

  @doc """
  GET /.well-known/oauth-protected-resource[/*path] (RFC 9728). `resource`
  names the exact URL the client connected to.
  """
  def protected_resource_metadata(conn, params) do
    base_url = MetricFlowWeb.Endpoint.url()

    resource =
      case params do
        %{"path" => [_ | _] = path} -> Enum.join([base_url | path], "/")
        _ -> base_url <> "/mcp"
      end

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(%{
      "resource" => resource,
      "authorization_servers" => [base_url],
      "scopes_supported" => ["read", "write"],
      "bearer_methods_supported" => ["header"]
    })
  end

  @doc "GET /.well-known/oauth-authorization-server[/*path] (RFC 8414)."
  def authorization_server_metadata(conn, _params) do
    base_url = MetricFlowWeb.Endpoint.url()

    conn
    |> put_resp_header("access-control-allow-origin", "*")
    |> json(%{
      "issuer" => base_url,
      "authorization_endpoint" => base_url <> "/oauth/authorize",
      "token_endpoint" => base_url <> "/oauth/token",
      "registration_endpoint" => base_url <> "/oauth/register",
      "revocation_endpoint" => base_url <> "/oauth/revoke",
      "scopes_supported" => ["read", "write"],
      "response_types_supported" => ["code"],
      "grant_types_supported" => ["authorization_code", "refresh_token"],
      "code_challenge_methods_supported" => ["S256"],
      "token_endpoint_auth_methods_supported" => ["client_secret_basic", "client_secret_post"]
    })
  end

  @doc "POST /oauth/register — Dynamic Client Registration (RFC 7591)."
  # shortcut: no rate limit on /oauth/register, add before public launch
  def register(conn, params) do
    grant_types = Map.get(params, "grant_types", ["authorization_code", "refresh_token"])
    redirect_uris = Map.get(params, "redirect_uris", [])
    scope = Map.get(params, "scope", "read write")

    with :ok <- validate_registration(grant_types, redirect_uris, scope),
         {:ok, application} <-
           Oauth.register_application(%{
             name: params["client_name"] || "MCP Client",
             redirect_uri: Enum.join(redirect_uris, " "),
             scopes: scope,
             uid: "mcp_" <> random(16),
             secret: random(32)
           }) do
      conn
      |> put_status(:created)
      |> json(%{
        "client_id" => application.uid,
        "client_secret" => application.secret,
        "client_secret_expires_at" => 0,
        "token_endpoint_auth_method" => registered_auth_method(params),
        "client_name" => application.name,
        "redirect_uris" => redirect_uris,
        "grant_types" => grant_types,
        "response_types" => ["code"],
        "scope" => application.scopes
      })
    else
      {:error, error, description} ->
        registration_error(conn, error, description)

      {:error, %Ecto.Changeset{} = changeset} ->
        error =
          if Keyword.has_key?(changeset.errors, :redirect_uri),
            do: "invalid_redirect_uri",
            else: "invalid_client_metadata"

        registration_error(conn, error, format_errors(changeset))
    end
  end

  # Every registered client gets a secret, so "none" is answered with the
  # method it must use instead; unstated means basic, the RFC 7591 default.
  defp registered_auth_method(%{"token_endpoint_auth_method" => "client_secret_post"}),
    do: "client_secret_post"

  defp registered_auth_method(_params), do: "client_secret_basic"

  defp validate_registration(grant_types, redirect_uris, scope) do
    cond do
      not is_list(grant_types) or grant_types == [] or
          not Enum.all?(grant_types, &(&1 in ["authorization_code", "refresh_token"])) ->
        {:error, "invalid_client_metadata",
         "grant_types must be authorization_code and/or refresh_token"}

      not is_list(redirect_uris) or redirect_uris == [] ->
        {:error, "invalid_redirect_uri", "redirect_uris must be a nonempty array"}

      not Enum.all?(redirect_uris, &(is_binary(&1) and &1 != "" and not (&1 =~ ~r/\s/u))) ->
        {:error, "invalid_redirect_uri", "redirect_uris must be URIs without whitespace"}

      not is_binary(scope) or not Enum.all?(String.split(scope), &(&1 in ["read", "write"])) ->
        {:error, "invalid_client_metadata", "Unsupported client scope"}

      true ->
        :ok
    end
  end

  defp registration_error(conn, error, description) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: error, error_description: description})
  end

  defp random(bytes), do: :crypto.strong_rand_bytes(bytes) |> Base.url_encode64(padding: false)

  defp format_errors(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, errors} -> "#{field}: #{Enum.join(errors, ", ")}" end)
  end
end
