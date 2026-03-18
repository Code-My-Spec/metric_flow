# Seed script creates integration with refresh token, preventing :not_connected error path

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The QA seed script  priv/repo/qa_seeds_440.exs  creates the expired  google_analytics  integration with  refresh_token: "qa_expired_refresh_token" . However,  DataSync.check_connected/1  only returns  {:error, :not_connected}  when the token is expired AND no refresh token is available: defp check_connected(%Integration{} = integration) do
  if Integration.expired?(integration) and not Integration.has_refresh_token?(integration) do
    {:error, :not_connected}
  else
    :ok
  end
end With a refresh token present,  check_connected/1  returns  :ok , the Oban job is dispatched, and the flash shown to the user is  "Sync started for Google Analytics"  — not the reconnection message. Scenario 3 of the brief (testing that "Sync Now" shows a reconnection flash) cannot be exercised with the current seed. To test the  :not_connected  path, the seed script should create the integration without a  refresh_token  (or with  refresh_token: nil ). Update  priv/repo/qa_seeds_440.exs  to remove the  refresh_token  field or set it to  nil .

## Source

QA Story 440 — `.code_my_spec/qa/440/result.md`

## Resolution

Fixed priv/repo/qa_seeds_440.exs to remove the refresh_token field (set to nil) from both the insert and update branches. Previously the seed created the google_analytics integration with refresh_token: 'qa_expired_refresh_token', which caused DataSync.check_connected/1 to return :ok instead of {:error, :not_connected}, preventing Scenario 3 from being tested. With refresh_token: nil, the expired token check now correctly triggers the :not_connected path and shows the reconnection flash. Files changed: priv/repo/qa_seeds_440.exs. Verified by code inspection of DataSync.check_connected/1 logic.
