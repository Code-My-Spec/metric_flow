alias MetricFlow.Integrations.Integration
alias MetricFlow.{Repo, Users}

user = Users.get_user_by_email("qa@example.com")

existing = Repo.get_by(Integration, user_id: user.id, provider: :google_ads)

if is_nil(existing) do
  %Integration{}
  |> Integration.changeset(%{
    user_id: user.id,
    provider: :google_ads,
    access_token: "qa_test_token",
    refresh_token: "qa_test_refresh",
    expires_at: DateTime.add(DateTime.utc_now(), 86_400, :second),
    granted_scopes: ["https://www.googleapis.com/auth/adwords"],
    provider_metadata: %{
      "email" => "qa@example.com",
      "selected_accounts" => ["Campaign Alpha", "Campaign Beta"]
    }
  })
  |> Repo.insert!()
  IO.puts("Created google_ads integration for qa@example.com")
else
  IO.puts("Integration already exists (id=#{existing.id})")
end
