# MetricFlowWeb.IntegrationLive.Connect

OAuth connection flow for linking marketing platforms to a user account. Displays all supported platforms (Google Ads, Facebook Ads, Google Analytics) with their current connection status and per-platform OAuth initiation links. Also serves as the OAuth callback handler — when the user returns from the provider, the view processes the authorization code, persists the integration, and shows a confirmation or error message.

## Type

liveview

## Route

`/integrations/connect` — platform selection and status overview

`/integrations/connect/:provider` — per-platform detail view showing OAuth link and connection status

`/integrations/oauth/callback/:provider` — OAuth callback entry point; processes the authorization code and redirects to `/integrations/connect` with a flash message

## Params

- `provider` - atom string identifying the platform (e.g., `google_ads`, `facebook_ads`, `google_analytics`); required for the callback and per-platform routes
- `code` - string, OAuth authorization code returned by the provider on successful authorization (callback route only)
- `state` - string, CSRF state token returned by the provider (callback route only); matched against the value stored in the session
- `error` - string, OAuth error code returned by the provider on authorization failure (callback route only, e.g., `access_denied`)
- `error_description` - string, human-readable error detail from the provider (callback route only, optional)

## Dependencies

- MetricFlow.Integrations

## Components

None

## User Interactions

- **phx-click="connect"**: Triggered when a user clicks the Connect button for a platform on the `/integrations/connect` listing page. Calls `Integrations.authorize_url/1` with the provider atom. On success, redirects the browser to the returned OAuth authorization URL using a standard redirect (not a live redirect) so the browser opens the provider login page. Sets the `session_params` in the socket session for CSRF validation on callback. On `{:error, :unsupported_provider}`, shows an error flash "This platform is not yet supported". On other errors, shows an error flash "Could not initiate connection. Please try again."

- **mount (callback route)**: When the LiveView mounts at `/integrations/oauth/callback/:provider`, it reads the `code`, `state`, and `error` query parameters from params. If the `error` param is present, skips token exchange and assigns `status: :error` and an `error_message` derived from the `error` param (e.g., "Access was denied" for `access_denied`). If `code` is present, calls `Integrations.handle_callback/4` with the current scope, provider atom, session params from the session, and the callback params map. On `{:ok, %Integration{}}`, assigns `status: :connected` and the integration. On `{:error, reason}`, assigns `status: :error` and a generic error message. Unauthenticated users are redirected to `/users/log-in` by the router's authentication plug before mount.

## Design

Layout: Single-column, centered page with `max-w-3xl` container, wrapped in `mf-content` for correct z-index above the aurora background.

Page header: Title "Connect a Platform" with a subtitle "Link your marketing accounts to start syncing data" using `text-base-content/60`.

**Platform selection view (`/integrations/connect`):**

A responsive grid of platform cards using `grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4`. Each card is an `mf-card` panel with `p-5` padding and a `data-platform="{provider_key}"` attribute on the outermost element.

Each platform card contains:
- Platform logo or icon area: a rounded `bg-base-300/40` square icon placeholder or SVG icon
- Platform name in `font-semibold` (e.g., "Google Ads", "Facebook Ads", "Google Analytics")
- A brief one-line description of what the platform provides (e.g., "Paid search and display advertising")
- Connection status badge: `.badge .badge-success` with text "Connected" when an active integration exists; `.badge .badge-ghost` with text "Not connected" otherwise
- Connect / Reconnect button: `.btn .btn-primary .btn-sm` labeled "Connect" (or "Reconnect" if already connected), with `data-role="connect-button"` and `phx-click="connect"` and `phx-value-provider="{provider_key}"`. The button opens the OAuth provider's authorization page via a standard browser redirect.

**Per-platform detail view (`/integrations/connect/:provider`):**

An `mf-card` panel centered with `max-w-sm mx-auto` showing:
- Platform name as the card title
- Current connection status badge
- If not connected: a descriptive paragraph and an OAuth initiation anchor tag rendered as `.btn .btn-primary` with `data-role="oauth-connect-button"` pointing to the authorize URL, opening in a new tab via `target="_blank" rel="noopener noreferrer"`. The href is pre-computed at mount via `Integrations.authorize_url/1` and stored in assigns.
- If already connected: confirmation text showing the connected account email from `integration.provider_metadata["email"]`, a "Connected" success badge, and a "Reconnect" link to refresh the token.
- Navigation link: `.btn .btn-ghost .btn-sm` labeled "Back to integrations" linking to `/integrations`.

**OAuth callback view (`/integrations/oauth/callback/:provider`):**

A centered `mf-card` with `max-w-sm mx-auto` used as a transient processing or result screen:

- While processing (before mount completes): a loading spinner `.loading .loading-spinner` with text "Connecting your account..."

- On success (`status: :connected`):
  - A success icon or green checkmark in `text-success`
  - Heading "Integration Active" in `font-semibold`
  - Body text: "Your [Platform Name] account is connected and ready to sync data."
  - `.badge .badge-success` labeled "Active"
  - `.btn .btn-primary` labeled "View Integrations" linking to `/integrations`
  - `.btn .btn-ghost .btn-sm` labeled "Connect another platform" linking to `/integrations/connect`

- On error (`status: :error`):
  - An error icon in `text-error`
  - Heading "Connection Failed" in `font-semibold text-error`
  - Body text showing the `error_message` assign
  - `.btn .btn-primary` labeled "Try again" linking to `/integrations/connect/:provider`
  - `.btn .btn-ghost .btn-sm` labeled "Back to integrations" linking to `/integrations`

Components: `.mf-card`, `.mf-content`, `.btn`, `.btn-primary`, `.btn-ghost`, `.btn-sm`, `.badge`, `.badge-success`, `.badge-ghost`, `.loading`, `.loading-spinner`, `.grid`

Responsive: Platform cards wrap to a single column on mobile. The per-platform and callback cards display at full width on mobile, centered with `max-w-sm` on larger screens. Connect buttons span full width on mobile (`w-full sm:w-auto`).
