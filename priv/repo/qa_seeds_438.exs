alias MetricFlow.Integrations
alias MetricFlow.Integrations.Integration
alias MetricFlow.Repo
alias MetricFlow.Users
alias MetricFlow.Users.Scope

user = Users.get_user_by_email("qa@example.com")
scope = Scope.for_user(user)

existing = Integrations.list_integrations(scope) |> Enum.find(&(&1.provider == :google))

if existing do
  IO.puts("Google integration already exists for qa@example.com (id=#{existing.id})")
else
  %Integration{}
  |> Integration.changeset(%{
    user_id: user.id,
    provider: :google,
    access_token: "qa_test_access_token",
    refresh_token: "qa_test_refresh_token",
    expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
    granted_scopes: ["https://www.googleapis.com/auth/analytics.readonly"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "selected_accounts" => ["UA-12345 (Main Site)", "GA4-67890 (App)"]
    }
  })
  |> Repo.insert!()
  IO.puts("Created Google integration for qa@example.com")
end
