defmodule MetricFlow.DataSync.ProviderHttp do
  @moduledoc """
  Req requests with optional, process-local capture of provider failure details.

  Capture is scoped to one synchronous provider invocation and restored even
  when it raises. Direct provider callers keep their existing return contracts.
  """

  @capture_key {__MODULE__, :capture}
  @max_body_bytes 16_384

  def capture(fun, secrets \\ []) do
    previous = Process.get(@capture_key)
    Process.put(@capture_key, %{detail: nil, secrets: secrets})

    try do
      result = fun.()
      {result, Process.get(@capture_key).detail}
    after
      if is_nil(previous),
        do: Process.delete(@capture_key),
        else: Process.put(@capture_key, previous)
    end
  end

  def request(opts) do
    case Req.request(opts) do
      {:ok, response} = result ->
        capture_response(response)
        result

      other ->
        other
    end
  end

  def request!(opts) do
    response = Req.request!(opts)
    capture_response(response)
    response
  end

  def get!(opts), do: request!(Keyword.put(opts, :method, :get))

  defp capture_response(%Req.Response{status: status, body: body}) do
    case Process.get(@capture_key) do
      nil ->
        :ok

      state ->
        if status >= 400 or error_body?(body) do
          text = body |> redact_fields() |> encode_body()

          text =
            Enum.reduce(state.secrets, text, fn
              secret, acc when is_binary(secret) and byte_size(secret) > 0 ->
                String.replace(acc, secret, "[REDACTED]")

              _, acc ->
                acc
            end)

          text = String.replace(text, ~r/Bearer\s+[^\s"<>]+/i, "Bearer [REDACTED]")
          truncated = byte_size(text) > @max_body_bytes
          text = if truncated, do: truncate_utf8(text, @max_body_bytes, []), else: text
          detail = %{"status" => status, "body" => text, "truncated" => truncated}
          Process.put(@capture_key, %{state | detail: detail})
        end
    end
  end

  defp error_body?(body) when is_map(body),
    do: not is_nil(body["error"]) or not is_nil(body["Fault"])

  defp error_body?(_), do: false

  defp redact_fields(body) when is_map(body) do
    Map.new(body, fn {key, value} ->
      if String.downcase(to_string(key)) in [
           "access_token",
           "refresh_token",
           "id_token",
           "authorization",
           "client_secret",
           "developer-token",
           "developer_token",
           "password"
         ] do
        {key, "[REDACTED]"}
      else
        {key, redact_fields(value)}
      end
    end)
  end

  defp redact_fields(body) when is_list(body), do: Enum.map(body, &redact_fields/1)

  defp redact_fields(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} when is_map(decoded) or is_list(decoded) -> redact_fields(decoded)
      _ -> body
    end
  end

  defp redact_fields(body), do: body

  defp truncate_utf8(<<codepoint::utf8, rest::binary>>, remaining, acc) do
    encoded = <<codepoint::utf8>>

    if byte_size(encoded) <= remaining do
      truncate_utf8(rest, remaining - byte_size(encoded), [encoded | acc])
    else
      acc |> Enum.reverse() |> IO.iodata_to_binary()
    end
  end

  defp truncate_utf8(_rest, _remaining, acc),
    do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp encode_body(body) when is_binary(body), do: body
  defp encode_body(body), do: Jason.encode!(body)
end
