defmodule MetricFlow.Oauth.AccessToken do
  @moduledoc "An OAuth access/refresh token issued to an MCP client (ex_oauth2_provider)."
  use Ecto.Schema
  use ExOauth2Provider.AccessTokens.AccessToken, otp_app: :metric_flow

  schema "oauth_access_tokens" do
    access_token_fields()

    timestamps()
  end
end
