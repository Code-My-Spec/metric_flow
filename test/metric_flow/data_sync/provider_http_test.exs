defmodule MetricFlow.DataSync.ProviderHttpTest do
  use ExUnit.Case, async: true

  alias MetricFlow.DataSync.ProviderHttp

  defp request_opts(status, body) do
    [
      url: "https://provider.example/report",
      retry: false,
      plug: fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("application/json")
        |> Plug.Conn.send_resp(status, Jason.encode!(body))
      end
    ]
  end

  test "captures diagnostics without changing the response and redacts credentials" do
    body = %{
      "error" => %{
        "message" => "Denied for secret-access",
        "access_token" => "other-secret",
        "details" => [%{"client_secret" => "hidden"}]
      }
    }

    {{:ok, response}, detail} =
      ProviderHttp.capture(
        fn ->
          ProviderHttp.request(request_opts(403, body))
        end,
        ["secret-access"]
      )

    assert response.body == body
    assert detail["status"] == 403
    assert detail["body"] =~ "Denied for [REDACTED]"
    refute detail["body"] =~ "secret-access"
    refute detail["body"] =~ "other-secret"
    refute detail["body"] =~ "hidden"
  end

  test "capture is isolated between invocations and cleaned up after exceptions" do
    assert_raise RuntimeError, "fetch failed", fn ->
      ProviderHttp.capture(fn ->
        ProviderHttp.request!(request_opts(403, %{"error" => "first failure"}))
        raise "fetch failed"
      end)
    end

    {response, detail} =
      ProviderHttp.capture(fn ->
        ProviderHttp.get!(request_opts(200, %{"rows" => []}))
      end)

    assert response.status == 200
    assert is_nil(detail)

    ProviderHttp.request!(request_opts(403, %{"error" => "outside capture"}))
    assert {:ok, nil} = ProviderHttp.capture(fn -> :ok end)
  end

  test "captures provider error envelopes returned with HTTP 200" do
    {_, detail} =
      ProviderHttp.capture(fn ->
        ProviderHttp.request!(request_opts(200, %{"error" => %{"code" => 190}}))
      end)

    assert detail["status"] == 200
    assert Jason.decode!(detail["body"])["error"]["code"] == 190
  end

  test "bounds diagnostic payloads and marks truncation" do
    {_, detail} =
      ProviderHttp.capture(fn ->
        ProviderHttp.request!(request_opts(403, %{"error" => String.duplicate("x́", 30_000)}))
      end)

    assert detail["truncated"]
    assert byte_size(detail["body"]) <= 16_384
    assert String.valid?(detail["body"])
  end
end
