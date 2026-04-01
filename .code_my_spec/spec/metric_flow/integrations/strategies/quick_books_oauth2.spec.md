# MetricFlow.Integrations.Strategies.QuickBooksOauth2

Custom Assent OAuth2 strategy for QuickBooks Online that skips the userinfo fetch. QuickBooks uses OAuth 2.0 for token exchange but does not reliably support the OpenID Connect userinfo endpoint for the `com.intuit.quickbooks.accounting` scope. The `realmId` (company ID) is returned as a query parameter on the callback URL rather than from a userinfo endpoint. This strategy overrides the base OAuth2 behavior to complete token exchange without a userinfo HTTP call, returning an empty map as the user payload.

## Type

module

## Dependencies

- None

## Functions

