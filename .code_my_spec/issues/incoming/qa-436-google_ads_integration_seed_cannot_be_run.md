# google_ads integration seed cannot be run while server is active

## Status

dismissed

## Severity

medium

## Scope

qa

## Description

The brief instructs running a  mix run -e '...'  one-liner to create a google_ads integration with  selected_accounts  in  provider_metadata . This fails when the Phoenix server is already running because the Cloudflare tunnel GenServer conflicts with the  mix run  process attempting to start the application. The brief acknowledges this is a "one-off seed step" but does not provide an alternative for the server-running scenario. As a result, the selected_accounts scenario (Scenario 6) and the "Google Ads" platform name scenarios could not be tested with the intended seed data. Resolution options: (1) Add a  --no-start  compatible version of the seed using  Repo.start_link  and skipping Cloudflare, (2) Add the google_ads integration to  priv/repo/qa_seeds.exs  as an idempotent step, or (3) Use a Mix task that bypasses the full application startup.

## Source

QA Story 436 — `.code_my_spec/qa/436/result.md`
