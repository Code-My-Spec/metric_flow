defmodule MetricFlow.Integrations.GoogleApiError do
  @moduledoc """
  Turns a Google API error response into a reason a person can act on.

  Google says why in the body: an API switched off in the Cloud project, a
  Google Ads developer token that isn't approved, or a plain message. A bare
  status code (`:bad_request`) tells nobody what to do.
  """

  @developer_token_codes ~w(DEVELOPER_TOKEN_NOT_APPROVED DEVELOPER_TOKEN_PROHIBITED
                            DEVELOPER_TOKEN_INVALID DEVELOPER_TOKEN_PARAMETER_MISSING
                            DEVELOPER_TOKEN_HEADER_INVALID)

  @type reason ::
          :api_disabled
          | {:google_ads_developer_token, String.t()}
          | {:google_api_error, pos_integer(), String.t() | nil}

  @spec reason(pos_integer(), term()) :: reason()
  def reason(status, body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> reason(status, decoded)
      {:error, _} -> {:google_api_error, status, nil}
    end
  end

  def reason(status, %{"error" => %{} = error}) do
    codes = error_codes(error)

    cond do
      "SERVICE_DISABLED" in codes or "accessNotConfigured" in codes ->
        :api_disabled

      code = Enum.find(codes, &(&1 in @developer_token_codes)) ->
        {:google_ads_developer_token, code}

      true ->
        {:google_api_error, status, error["message"]}
    end
  end

  def reason(status, _body), do: {:google_api_error, status, nil}

  # Codes live in three places depending on the API: `errors[].reason`
  # (classic), `details[].reason` (ErrorInfo), and Google Ads'
  # `details[].errors[].errorCode` map.
  defp error_codes(error) do
    classic = Enum.map(List.wrap(error["errors"]), &reason_of/1)
    details = List.wrap(error["details"])
    info = Enum.map(details, &reason_of/1)

    ads =
      for %{"errors" => errors} <- details,
          %{"errorCode" => %{} = code} <- List.wrap(errors),
          value <- Map.values(code),
          do: value

    Enum.filter(classic ++ info ++ ads, &is_binary/1)
  end

  defp reason_of(%{"reason" => reason}), do: reason
  defp reason_of(_), do: nil
end
