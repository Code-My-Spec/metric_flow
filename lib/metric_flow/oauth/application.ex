defmodule MetricFlow.Oauth.Application do
  @moduledoc "A registered OAuth client (an MCP client such as Claude or ChatGPT)."
  use Ecto.Schema
  use ExOauth2Provider.Applications.Application, otp_app: :metric_flow
  import Ecto.Changeset

  schema "oauth_applications" do
    application_fields()

    timestamps()
  end

  def changeset(application, attrs) do
    application
    |> cast(attrs, [:name, :scopes, :uid, :secret, :redirect_uri])
    |> validate_required([:name, :uid, :secret, :redirect_uri])
    |> validate_redirect_uris()
    |> unique_constraint(:uid)
  end

  # HTTPS, except http on localhost for native/CLI clients (RFC 8252).
  defp validate_redirect_uris(changeset) do
    validate_change(changeset, :redirect_uri, fn :redirect_uri, redirect_uri ->
      redirect_uri
      |> String.split(" ", trim: true)
      |> Enum.flat_map(fn uri ->
        case redirect_uri_error(URI.parse(uri)) do
          nil -> []
          message -> [redirect_uri: message]
        end
      end)
    end)
  end

  defp redirect_uri_error(%URI{scheme: "https"}), do: nil

  defp redirect_uri_error(%URI{scheme: "http", host: host})
       when host in ["localhost", "127.0.0.1", "::1"],
       do: nil

  defp redirect_uri_error(%URI{scheme: "http"}), do: "must use HTTPS except for localhost"
  defp redirect_uri_error(%URI{scheme: nil}), do: "must be an absolute URI with a scheme"
  defp redirect_uri_error(_uri), do: nil
end
