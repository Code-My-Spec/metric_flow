defmodule MetricFlow.DataSync.YouTubeSyncOutcomeTest do
  use ExUnit.Case, async: true

  alias MetricFlow.DataSync.YouTubeSyncOutcome

  test "partial success retains the sanitized provider message and successful count" do
    detail = %{
      "status" => 503,
      "body" =>
        Jason.encode!(%{
          "error" => %{"message" => "Channel analytics temporarily unavailable [REDACTED]"}
        })
    }

    result =
      YouTubeSyncOutcome.summarize(
        {:ok,
         [
           %{
             channel_id: "UC_test",
             family: "analytics",
             result: {:error, {:provider_http_error, {:http_error, 503}, detail}}
           },
           %{channel_id: "UC_test", family: "revenue", result: {:ok, %{observations_written: 3}}}
         ]}
      )

    assert result.status == :partial_success
    assert result.records_synced == 3
    assert result.error_message =~ "Channel analytics temporarily unavailable [REDACTED]"
    assert result.provider_error_detail == detail
  end

  test "malformed or missing provider messages retain the generic error" do
    for body <- ["truncated {", "{}", Jason.encode!(%{"error" => %{"message" => nil}})] do
      result =
        YouTubeSyncOutcome.summarize(
          {:error, {:provider_http_error, {:http_error, 503}, %{"body" => body}}}
        )

      assert result.error_message == "YouTube returned HTTP 503."
    end
  end
end
