# Integrations index and connect pages have mixed responsibilities — sync controls on wrong page

## Status

resolved

## Severity

medium

## Scope

app

## Description

The /integrations page shows connections (Google, Facebook, QuickBooks) with Sync Now buttons and sync status. The /integrations/connect page shows individual platforms (Google Ads, Google Analytics, Facebook Ads, QuickBooks) as separate cards. The responsibilities are mixed up: sync controls (Sync Now, sync status, last synced) are on the /integrations page which shows high-level connections, but syncing happens per-platform (GA4, Google Ads separately). The sync controls should probably be on the /integrations/connect page where individual platforms are listed, or the /integrations page should show per-platform sync status instead of per-connection. Currently a single Google connection syncs both GA4 and Ads, but the UI doesn't surface which platform succeeded or failed.

## Source

Braindump import

## Resolution

Acknowledged as an architecture/design concern. The current split between /integrations (connections with sync controls) and /integrations/connect (individual platforms) needs a design review to determine the right information hierarchy. Deferring to a design session rather than a code fix, as it requires product decisions about how to surface per-platform sync status vs per-connection status.
