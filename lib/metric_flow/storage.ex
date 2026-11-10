defmodule MetricFlow.Storage do
  @moduledoc "Generates short-lived upload URLs for agency branding assets in Tigris."

  alias ExAws.S3

  @logo_types %{
    ".png" => "image/png",
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".svg" => "image/svg+xml"
  }

  @doc "Signs a logo upload without transferring file bytes through the application."
  def presign_logo_upload(entry, opts \\ []) do
    extension = entry.client_name |> Path.extname() |> String.downcase()
    bucket = Keyword.get(opts, :bucket, System.get_env("BUCKET_NAME"))
    access_key = credential(opts, :access_key_id, "AWS_ACCESS_KEY_ID")
    secret_key = credential(opts, :secret_access_key, "AWS_SECRET_ACCESS_KEY")

    cond do
      Map.get(@logo_types, extension) != entry.client_type ->
        {:error, :unsupported_file_type}

      entry.client_size <= 0 or entry.client_size > 2_000_000 ->
        {:error, :invalid_file_size}

      not Enum.all?([bucket, access_key, secret_key], &(is_binary(&1) and &1 != "")) ->
        {:error, :storage_unavailable}

      true ->
        sign_upload(bucket, access_key, secret_key, extension, entry.client_type)
    end
  end

  defp credential(opts, key, environment_key) do
    Keyword.get(opts, key) || Application.get_env(:ex_aws, key) || System.get_env(environment_key)
  end

  defp sign_upload(bucket, access_key, secret_key, extension, content_type) do
    key = "logos/#{Ecto.UUID.generate()}#{extension}"

    config = %{
      scheme: "https://",
      host: "fly.storage.tigris.dev",
      port: 443,
      region: "auto",
      access_key_id: access_key,
      secret_access_key: secret_key
    }

    case S3.presigned_url(config, :put, bucket, key,
           expires_in: 300,
           headers: [{"content-type", content_type}]
         ) do
      {:ok, url} ->
        {:ok,
         %{
           uploader: "S3",
           key: key,
           url: url,
           public_url: "https://fly.storage.tigris.dev/#{bucket}/#{key}"
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
