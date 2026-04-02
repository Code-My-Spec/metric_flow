# MetricFlowWeb.IntegrationLive.Connect

OAuth connection flow for linking providers to a user account. Displays OAuth providers (Google, Facebook, QuickBooks) — not individual data platforms — with their current connection status and per-provider OAuth initiation links. Google covers both Google Ads and Google Analytics via a single OAuth connection.

## Type

liveview

## Route

`/integrations/connect` — provider selection and status overview

`/integrations/connect/:provider` — per-provider detail view showing OAuth link and connection status

`/integrations/oauth/callback/:provider` — OAuth callback entry point (controller); processes the authorization code and redirects to `/integrations/connect/:provider` with a flash message

## Params

- `provider` - atom string identifying the OAuth provider (e.g., `google`, `facebook_ads`, `quickbooks`); required for the callback and per-provider routes
- `code` - string, OAuth authorization code returned by the provider on successful authorization (callback route only)
- `state` - string, CSRF state token returned by the provider (callback route only); matched against the value stored in the session
- `error` - string, OAuth error code returned by the provider on authorization failure (callback route only, e.g., `access_denied`)
- `error_description` - string, human-readable error detail from the provider (callback route only, optional)

## Dependencies

- MetricFlow.Integrations

## Components

None

## User Interactions

- **phx-click="connect"**: Triggered when a user clicks the Connect button for a provider on the `/integrations/connect` listing page. Redirects the browser to `/integrations/oauth/:provider` which generates the OAuth authorization URL and redirects to the provider. On return, the OAuth callback controller processes the code and redirects back to `/integrations/connect/:provider`.

- **OAuth callback (controller)**: The `IntegrationOauthController` handles `/integrations/oauth/callback/:provider`. It exchanges the authorization code for tokens via `Integrations.handle_callback/4`, persists the integration, and redirects to `/integrations/connect/:provider` with a success or error flash.

## Design

Layout: Single-column, centered page with `max-w-3xl` container, wrapped in `mf-content` for correct z-index above the aurora background.

Page header: Title "Connect a Provider" with a subtitle "Authenticate with your marketing providers to start syncing data" using `text-base-content/60`.

**Provider selection view (`/integrations/connect`):**

A responsive grid of provider cards using `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4`. Each card is an `mf-card` panel with `p-5` padding and a `data-platform="{provider_key}"` attribute on the outermost element.

Each provider card contains:
- Provider logo or icon area: a rounded `bg-base-300/40` square icon placeholder
- Provider name in `font-semibold` (e.g., "Google", "Facebook", "QuickBooks")
- A brief one-line description (e.g., "Google Ads and Google Analytics")
- Connection status badge: `.badge .badge-success` with text "Connected" when an active integration exists; `.badge .badge-ghost` with text "Not connected" otherwise
- Connect / Reconnect button: `.btn .btn-primary .btn-sm` labeled "Connect" (or "Reconnect" if already connected), with `data-role="connect-button"` and `phx-click="connect"` and `phx-value-provider="{provider_key}"`. The button redirects to the OAuth controller request route.

**Per-provider detail view (`/integrations/connect/:provider`):**

An `mf-card` panel centered with `max-w-sm mx-auto` showing:
- Provider name as the card title
- Current connection status badge
- If not connected: a descriptive paragraph and an OAuth initiation anchor tag rendered as `.btn .btn-primary` with `data-role="oauth-connect-button"` pointing to the authorize URL, opening in a new tab via `target="_blank" rel="noopener noreferrer"`. The href is pre-computed at mount via `Integrations.authorize_url/1` and stored in assigns.
- If already connected: confirmation text showing the connected account email from `integration.provider_metadata["email"]`, a "Connected" success badge, and a "Reconnect" link to refresh the token.
- Navigation link: `.btn .btn-ghost .btn-sm` labeled "Back to integrations" linking to `/integrations`.

**OAuth result view (flash-based):**

When the OAuth callback redirects back to `/integrations/connect/:provider` with a flash:

- On success (flash info "Successfully connected!"):
  - A success icon or green checkmark in `text-success`
  - Heading "Integration Active" in `font-semibold`
  - Body text: "Your [Provider Name] account is connected and ready to sync data."
  - `.badge .badge-success` labeled "Active"
  - `.btn .btn-primary` labeled "View Integrations" linking to `/integrations`
  - `.btn .btn-ghost .btn-sm` labeled "Connect another platform" linking to `/integrations/connect`

- On error (flash error):
  - An error icon in `text-error`
  - Heading "Connection Failed" in `font-semibold text-error`
  - Body text showing the error message
  - `.btn .btn-primary` labeled "Try again" linking to `/integrations/connect/:provider`
  - `.btn .btn-ghost .btn-sm` labeled "Back to integrations" linking to `/integrations`

Components: `.mf-card`, `.mf-content`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.badge`, `.badge-success`, `.badge-ghost`, `.grid`

Responsive: Provider cards wrap to a single column on mobile. The per-provider and result cards display at full width on mobile, centered with `max-w-sm` on larger screens. Connect buttons span full width on mobile (`w-full sm:w-auto`).
