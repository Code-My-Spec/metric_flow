defmodule MetricFlow.Oauth.AccessGrant do
  @moduledoc """
  An authorization code (ex_oauth2_provider), plus the PKCE challenge it was
  issued against. `MetricFlow.Oauth` records the challenge after the library
  creates the grant and checks the verifier before the library redeems it.
  """
  use Ecto.Schema
  use ExOauth2Provider.AccessGrants.AccessGrant, otp_app: :metric_flow

  schema "oauth_access_grants" do
    access_grant_fields()

    field :code_challenge, :string
    field :code_challenge_method, :string

    timestamps()
  end
end
