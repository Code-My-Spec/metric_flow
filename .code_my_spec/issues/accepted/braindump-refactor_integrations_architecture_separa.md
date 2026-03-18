# Refactor integrations architecture: separate connections from platform syncing

## Status

resolved

## Severity

high

## Scope

docs

## Description

The specs and implementation conflate OAuth connections (Google, Facebook, QuickBooks) with data platforms (Google Analytics, Google Ads, Facebook Ads, QuickBooks). connect.spec.md lists individual platforms as connect targets but OAuth is per-provider — trying to connect to google_analytics fails because the OAuth provider is :google. index.spec.md has sync controls at the connection level but syncing is per-platform. Proposed: /connections manages OAuth provider connections. /integrations manages per-platform sync controls, account/property selection, and sync history. Specs need rewriting to reflect this separation.

## Source

Braindump import

## Resolution

Refactored. Connect page now shows OAuth providers (Google, Facebook, QuickBooks). Integrations page now shows data platforms (GA4, Google Ads, Facebook Ads, QuickBooks) with per-platform sync. Both specs updated.
