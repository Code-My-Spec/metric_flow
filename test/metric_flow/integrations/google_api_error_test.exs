defmodule MetricFlow.Integrations.GoogleApiErrorTest do
  use ExUnit.Case, async: true

  alias MetricFlow.Integrations.GoogleApiError
  alias MetricFlow.Onboarding

  test "a disabled API, in either place Google reports it" do
    errorinfo = %{"error" => %{"details" => [%{"reason" => "SERVICE_DISABLED"}]}}
    classic = %{"error" => %{"errors" => [%{"reason" => "accessNotConfigured"}]}}

    assert GoogleApiError.reason(403, errorinfo) == :api_disabled
    assert GoogleApiError.reason(403, Jason.encode!(classic)) == :api_disabled
  end

  test "a Google Ads developer token problem names the code" do
    body = %{
      "error" => %{
        "code" => 403,
        "message" => "The caller does not have permission",
        "details" => [
          %{
            "@type" => "type.googleapis.com/google.ads.googleads.v18.errors.GoogleAdsFailure",
            "errors" => [
              %{"errorCode" => %{"authorizationError" => "DEVELOPER_TOKEN_NOT_APPROVED"}}
            ]
          }
        ]
      }
    }

    reason = GoogleApiError.reason(403, body)
    assert reason == {:google_ads_developer_token, "DEVELOPER_TOKEN_NOT_APPROVED"}
    assert Onboarding.explain_error(reason) =~ "developer token"
  end

  test "anything else keeps Google's message" do
    body = %{"error" => %{"code" => 400, "message" => "Request contains an invalid argument."}}
    reason = GoogleApiError.reason(400, body)

    assert reason == {:google_api_error, 400, "Request contains an invalid argument."}
    assert Onboarding.explain_error(reason) =~ "invalid argument"
    assert GoogleApiError.reason(400, "<html>") == {:google_api_error, 400, nil}
  end
end
