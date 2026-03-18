# Seed data drift — stale integrations from prior test runs

## Status

accepted

## Severity

low

## Scope

qa

## Description

The QA plan and brief document that  qa@example.com  has a Google integration ( provider: :google ) seeded via  priv/repo/qa_seeds.exs . However, the active account on this run showed a Facebook Ads integration as connected, with Google Analytics and Google Ads in the "Available" section. The seed script creates the Google integration but does not clean up other integrations that may have been added during prior test runs. The QA seeds should clear and re-create the Google integration on each run to ensure consistent state. Additionally, the BDD specs specifically reference  [data-platform='google_analytics'] button[phx-click='sync']  — this selector would not match in the current state since Google Analytics is in the "available" section.

## Source

QA Story 438 — `.code_my_spec/qa/438/result.md`
