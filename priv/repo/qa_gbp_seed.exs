alias MetricFlow.{Repo}
import Ecto.Query

alias MetricFlow.Accounts.User
alias MetricFlow.Integrations.Integration

user = Repo.one(from u in User, where: u.email == ^"qa@example.com")

if user do
  existing = Repo.one(from i in Integration, where: i.user_id == ^user.id and i.provider == :google_business)
  if is_nil(existing) do
    result =
      %Integration{}
      |> Integration.changeset(%{
        user_id: user.id,
        provider: :google_business,
        access_token: "test_access_token_gbp",
        refresh_token: "test_refresh_token_gbp",
        expires_at: DateTime.add(DateTime.utc_now(), 3600, :second),
        granted_scopes: ["https://www.googleapis.com/auth/business.manage"],
        provider_metadata: %{
          "email" => "qa@example.com",
          "google_business_account_ids" => ["accounts/123", "accounts/456"]
        }
      })
      |> Repo.insert()
    case result do
      {:ok, _} -> IO.puts("Created google_business integration for qa@example.com")
      {:error, cs} -> IO.inspect(cs, label: "Error")
    end
  else
    IO.puts("google_business integration already exists")
  end
else
  IO.puts("ERROR: qa@example.com not found")
end
