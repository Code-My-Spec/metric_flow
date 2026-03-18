# priv/repo/qa_seeds_440.exs
#
# Story 440 — Handle Expired or Invalid OAuth Credentials
#
# Creates a google_analytics integration for qa@example.com with an EXPIRED
# access token and NO refresh token so the integrations page shows a
# connected-but-expired state that triggers the :not_connected error path.
#
# Idempotent — safe to run multiple times. If an integration already exists
# it updates the expires_at to be in the past and clears the refresh token.
#
# Usage: mix run priv/repo/qa_seeds_440.exs

import Ecto.Query

alias MetricFlow.Integrations.Integration
alias MetricFlow.{Repo, Users}

IO.puts("\n--- Story 440 seeds: expired google_analytics integration (no refresh token) ---")

user = Users.get_user_by_email("qa@example.com")

if is_nil(user) do
  IO.puts("ERROR: qa@example.com not found. Run mix run priv/repo/qa_seeds.exs first.")
  System.halt(1)
end

# expired_at = 48 hours ago
expired_at = DateTime.add(DateTime.utc_now(), -172_800, :second)

existing =
  Repo.one(
    from i in Integration,
      where: i.user_id == ^user.id and i.provider == :google_analytics
  )

if is_nil(existing) do
  %Integration{}
  |> Integration.changeset(%{
    user_id: user.id,
    provider: :google_analytics,
    access_token: "qa_expired_access_token",
    refresh_token: nil,
    expires_at: expired_at,
    granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "property_id" => "properties/123456789"
    }
  })
  |> Repo.insert!()

  IO.puts("  Created expired google_analytics integration (no refresh token) for qa@example.com")
else
  existing
  |> Integration.changeset(%{expires_at: expired_at, refresh_token: nil})
  |> Repo.update!()

  IO.puts("  Updated existing google_analytics integration: expired and refresh token cleared (id=#{existing.id})")
end

IO.puts("""

==========================================
 Story 440 QA Seeds — Summary
==========================================

User:          qa@example.com / hello world!
Integration:   google_analytics (EXPIRED — no refresh token)
Effect:        Clicking "Sync Now" on this integration will trigger
               {:error, :not_connected} → flash error prompting reconnect

URL:           http://localhost:4070/integrations
Connect URL:   http://localhost:4070/integrations/connect/google_analytics
""")
