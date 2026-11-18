defmodule MetricFlow.Oauth do
  @moduledoc """
  OAuth 2.1 authorization server for MCP clients (Claude, ChatGPT, ...), so
  they connect to `/mcp` by URL and the user signs in instead of pasting a
  token. Backed by `ExOauth2Provider` (authorization-code + refresh grants).

  On top of the library:

    * **PKCE (S256) is mandatory.** Every authorization request must carry a
      `code_challenge` with `code_challenge_method=S256`
      (`validate_code_challenge/1`); the challenge is stored on the issued
      grant (`attach_code_challenge/2`) and the token endpoint verifies the
      `code_verifier` against it before the library redeems the code
      (`grant_token/1`). A grant without a stored challenge never redeems.
    * Refresh refuses revoked credentials and serializes per client with a
      row lock, so a revoked authorization can't be refreshed back to life.

  The resource owner is a `MetricFlow.Users.User`; what the token may do is
  decided per call by account membership (see `MetricFlow.Onboarding.Tools`).
  """

  use Boundary, deps: [MetricFlow, MetricFlow.Users], exports: [Application, AccessToken]

  import Ecto.Query, only: [from: 2]

  alias ExOauth2Provider.AccessTokens
  alias ExOauth2Provider.Authorization
  alias ExOauth2Provider.Token
  alias MetricFlow.Oauth.AccessGrant
  alias MetricFlow.Oauth.AccessToken
  alias MetricFlow.Oauth.Application
  alias MetricFlow.Repo
  alias MetricFlow.Users.User

  @config [otp_app: :metric_flow]

  # RFC 7636 §4.1/§4.2: 43-128 unreserved characters.
  @pkce_format ~r/\A[A-Za-z0-9\-._~]{43,128}\z/

  @doc "Registers an OAuth client (Dynamic Client Registration)."
  @spec register_application(map()) :: {:ok, Application.t()} | {:error, Ecto.Changeset.t()}
  def register_application(attrs) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  ## Authorization endpoint

  @doc """
  Checks the request carries a PKCE S256 challenge. Returns `:ok` or
  `{:error, description}`.
  """
  @spec validate_code_challenge(map()) :: :ok | {:error, String.t()}
  def validate_code_challenge(%{"code_challenge" => challenge} = params)
      when is_binary(challenge) do
    cond do
      params["code_challenge_method"] != "S256" ->
        {:error, "code_challenge_method must be S256"}

      not Regex.match?(@pkce_format, challenge) ->
        {:error, "code_challenge is malformed"}

      true ->
        :ok
    end
  end

  def validate_code_challenge(_params),
    do: {:error, "code_challenge is required (PKCE with S256)"}

  @doc "Library preauthorization (validates client, redirect and scopes)."
  def preauthorize(%User{} = user, params), do: Authorization.preauthorize(user, params, @config)

  @doc "Records the user's approval; issues an authorization code."
  def authorize(%User{} = user, params), do: Authorization.authorize(user, params, @config)

  @doc "Records the user's denial."
  def deny(%User{} = user, params), do: Authorization.deny(user, params, @config)

  @doc """
  Stores the request's PKCE challenge on the grant the library just issued.
  `issued` is the library's `{:redirect, uri}` / `{:native_redirect, %{code: c}}`
  result; anything else (an error redirect) is passed through untouched.
  """
  def attach_code_challenge({:redirect, uri} = result, params) do
    case URI.parse(uri).query do
      nil -> :ok
      query -> query |> URI.decode_query() |> Map.get("code") |> store_challenge(params)
    end

    result
  end

  def attach_code_challenge({:native_redirect, %{code: code}} = result, params) do
    store_challenge(code, params)
    result
  end

  def attach_code_challenge(result, _params), do: result

  defp store_challenge(code, params) when is_binary(code) do
    Repo.update_all(
      from(g in AccessGrant, where: g.token == ^code and is_nil(g.code_challenge)),
      set: [
        code_challenge: params["code_challenge"],
        code_challenge_method: params["code_challenge_method"]
      ]
    )

    :ok
  end

  defp store_challenge(_code, _params), do: :ok

  ## Token endpoint

  @doc """
  Issues tokens. Authorization codes must present the PKCE verifier for the
  challenge they were issued with; refresh refuses revoked credentials.
  """
  def grant_token(
        %{"grant_type" => "authorization_code", "client_id" => uid, "code" => code} = params
      )
      when is_binary(uid) and is_binary(code) do
    transaction(fn ->
      grant =
        Repo.one(
          from(g in AccessGrant,
            join: a in assoc(g, :application),
            where: a.uid == ^uid and g.token == ^code,
            lock: "FOR UPDATE"
          )
        )

      cond do
        is_nil(grant) ->
          invalid_grant("The authorization code is invalid")

        verify_code_verifier(grant, params["code_verifier"]) == :ok ->
          Token.grant(params, @config)

        true ->
          invalid_grant("PKCE verification failed")
      end
    end)
  end

  def grant_token(
        %{"grant_type" => "refresh_token", "client_id" => uid, "refresh_token" => r} = p
      )
      when is_binary(uid) and is_binary(r) do
    transaction(fn ->
      application = Repo.one(from(a in Application, where: a.uid == ^uid, lock: "FOR UPDATE"))

      token =
        application && Repo.get_by(AccessToken, application_id: application.id, refresh_token: r)

      case token do
        %AccessToken{revoked_at: nil} -> Token.grant(p, @config)
        _ -> invalid_grant("Refresh credential is unavailable")
      end
    end)
  end

  def grant_token(params), do: Token.grant(params, @config)

  defp verify_code_verifier(
         %AccessGrant{code_challenge: challenge, code_challenge_method: "S256"},
         verifier
       )
       when is_binary(challenge) and is_binary(verifier) do
    computed = :crypto.hash(:sha256, verifier) |> Base.url_encode64(padding: false)

    if Regex.match?(@pkce_format, verifier) and Plug.Crypto.secure_compare(computed, challenge),
      do: :ok,
      else: :error
  end

  defp verify_code_verifier(_grant, _verifier), do: :error

  defp invalid_grant(description),
    do: {:error, %{error: :invalid_grant, error_description: description}, :bad_request}

  defp transaction(fun) do
    case Repo.transaction(fun) do
      {:ok, result} ->
        result

      {:error, _reason} ->
        {:error, %{error: :server_error, error_description: "Token exchange failed"},
         :internal_server_error}
    end
  end

  @doc "Revokes a token (RFC 7009)."
  def revoke_token(params), do: Token.revoke(params, @config)

  ## Resource server

  @doc "The user id an access token acts for, when it is valid and unexpired."
  @spec verify_access_token(String.t()) :: {:ok, integer()} | {:error, :invalid}
  def verify_access_token(value) when is_binary(value) do
    case AccessTokens.get_by_token(value, @config) do
      %AccessToken{resource_owner_id: user_id} = token when is_integer(user_id) ->
        if accessible?(token), do: {:ok, user_id}, else: {:error, :invalid}

      _ ->
        {:error, :invalid}
    end
  end

  def verify_access_token(_value), do: {:error, :invalid}

  # Same rule as `AccessTokens.is_accessible?/1`, whose expiry helper emits a
  # deprecation warning on every call under Elixir 1.20.
  defp accessible?(%AccessToken{revoked_at: revoked_at}) when not is_nil(revoked_at), do: false
  defp accessible?(%AccessToken{expires_in: nil}), do: true

  defp accessible?(%AccessToken{expires_in: expires_in, inserted_at: inserted_at}) do
    NaiveDateTime.compare(NaiveDateTime.add(inserted_at, expires_in), NaiveDateTime.utc_now()) ==
      :gt
  end
end
