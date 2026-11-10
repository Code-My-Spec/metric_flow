defmodule MetricFlow.StorageTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Storage

  @options [
    bucket: "test-branding",
    access_key_id: "test-access-key",
    secret_access_key: "test-secret-key"
  ]

  test "signs supported logo types with expiring PUT credentials and unique public URLs" do
    for {name, type} <- [
          {"logo.png", "image/png"},
          {"logo.jpg", "image/jpeg"},
          {"logo.jpeg", "image/jpeg"},
          {"logo.svg", "image/svg+xml"}
        ] do
      entry = %{client_name: name, client_type: type, client_size: 100}
      assert {:ok, metadata} = Storage.presign_logo_upload(entry, @options)
      assert metadata.uploader == "S3"
      uri = URI.parse(metadata.url)
      query = URI.decode_query(uri.query)
      assert uri.scheme == "https"
      assert uri.host == "fly.storage.tigris.dev"
      assert uri.path == "/test-branding/#{metadata.key}"
      assert query["X-Amz-Expires"] == "300"
      assert query["X-Amz-SignedHeaders"] =~ "content-type"
      assert is_binary(query["X-Amz-Signature"])
      assert metadata.public_url == "https://fly.storage.tigris.dev/test-branding/#{metadata.key}"
      assert {:ok, second} = Storage.presign_logo_upload(entry, @options)
      refute second.key == metadata.key
    end
  end

  test "rejects unsupported extensions and mismatched content types" do
    for {name, type} <- [{"logo.gif", "image/gif"}, {"logo.png", "text/html"}] do
      entry = %{client_name: name, client_type: type, client_size: 100}
      assert {:error, :unsupported_file_type} = Storage.presign_logo_upload(entry, @options)
    end
  end

  test "rejects empty and oversized files" do
    for size <- [0, 2_000_001] do
      entry = %{client_name: "logo.png", client_type: "image/png", client_size: size}
      assert {:error, :invalid_file_size} = Storage.presign_logo_upload(entry, @options)
    end
  end

  test "returns an explicit error when the bucket is unavailable" do
    entry = %{client_name: "logo.png", client_type: "image/png", client_size: 100}
    options = Keyword.put(@options, :bucket, nil)
    assert {:error, :storage_unavailable} = Storage.presign_logo_upload(entry, options)
  end
end
