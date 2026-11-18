defmodule MetricFlow.Repo.Migrations.MergeGoogleIntegrationsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  @migration MetricFlow.Repo.Migrations.MergeGoogleIntegrations

  unless Code.ensure_loaded?(@migration) do
    Code.require_file(
      Path.expand(
        "../../../priv/repo/migrations/20261118100000_merge_google_integrations.exs",
        __DIR__
      )
    )
  end

  defp at(offset_seconds),
    do:
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(offset_seconds)
      |> NaiveDateTime.truncate(:second)

  # Inserts a pre-migration row; per-product Google providers are no longer
  # valid Integration providers, so it goes in schemaless.
  defp legacy!(attrs) do
    row =
      Map.merge(
        %{
          access_token: MetricFlow.Vault.encrypt!("access"),
          refresh_token: MetricFlow.Vault.encrypt!("refresh"),
          expires_at: at(3600),
          granted_scopes: [],
          provider_metadata: %{},
          inserted_at: at(0),
          updated_at: at(0)
        },
        attrs
      )

    {1, [%{id: id}]} = Repo.insert_all("integrations", [row], returning: [:id])
    id
  end

  defp sync_job!(integration_id, account_id) do
    now = at(0)

    {1, [%{id: id}]} =
      Repo.insert_all(
        "sync_jobs",
        [
          %{
            integration_id: integration_id,
            account_id: account_id,
            provider: "google_business",
            status: "completed",
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    id
  end

  defp sync_history!(integration_id, account_id, sync_job_id) do
    now = at(0)

    {1, [%{id: id}]} =
      Repo.insert_all(
        "sync_history",
        [
          %{
            integration_id: integration_id,
            account_id: account_id,
            sync_job_id: sync_job_id,
            provider: "google_business",
            status: "success",
            records_synced: 3,
            started_at: now,
            completed_at: now,
            inserted_at: now,
            updated_at: now
          }
        ],
        returning: [:id]
      )

    id
  end

  defp migrate!, do: @migration.merge(Repo)

  test "merges an account's Google product rows into one google integration" do
    user = user_fixture()
    other = user_fixture()
    account_id = default_account_id(user)

    ga =
      legacy!(%{
        provider: "google_analytics",
        account_id: account_id,
        user_id: user.id,
        expires_at: at(600),
        granted_scopes: ["email", "https://www.googleapis.com/auth/analytics.readonly"],
        provider_metadata: %{"email" => "old@example.com", "property_id" => "properties/1"},
        inserted_at: at(-86_400),
        updated_at: at(-86_400)
      })

    gbp =
      legacy!(%{
        provider: "google_business",
        account_id: account_id,
        user_id: other.id,
        access_token: MetricFlow.Vault.encrypt!("newest-access"),
        expires_at: at(3_600),
        granted_scopes: ["email", "https://www.googleapis.com/auth/business.manage"],
        provider_metadata: %{
          "email" => "new@example.com",
          "included_locations" => ["locations/9"],
          "google_business_account_ids" => ["accounts/1"]
        },
        inserted_at: at(-3_600),
        updated_at: at(-3_600)
      })

    job = sync_job!(gbp, account_id)
    history = sync_history!(gbp, account_id, job)

    # A different account's row is merged on its own.
    other_account = default_account_id(other)

    other_row =
      legacy!(%{provider: "google_ads", account_id: other_account, user_id: other.id})

    migrate!()

    assert [%Integration{} = google] =
             Repo.all(from(i in Integration, where: i.account_id == ^account_id))

    assert google.id == ga
    assert google.provider == :google
    assert google.user_id == user.id
    assert NaiveDateTime.compare(DateTime.to_naive(google.inserted_at), at(-86_400 - 5)) == :gt
    assert google.access_token == "newest-access"
    assert google.refresh_token == "refresh"

    assert Enum.sort(google.granted_scopes) ==
             Enum.sort([
               "email",
               "https://www.googleapis.com/auth/analytics.readonly",
               "https://www.googleapis.com/auth/business.manage"
             ])

    assert google.provider_metadata == %{
             "email" => "new@example.com",
             "property_id" => "properties/1",
             "included_locations" => ["locations/9"],
             "google_business_account_ids" => ["accounts/1"]
           }

    assert Repo.one!(from(j in "sync_jobs", where: j.id == ^job, select: j.integration_id)) == ga

    assert Repo.one!(from(h in "sync_history", where: h.id == ^history, select: h.integration_id)) ==
             ga

    assert %Integration{provider: :google} = Repo.get!(Integration, other_row)
  end

  test "keeps an existing google row and prefers a token that can refresh" do
    user = user_fixture()
    account_id = default_account_id(user)

    google =
      legacy!(%{
        provider: "google",
        account_id: account_id,
        user_id: user.id,
        refresh_token: nil,
        expires_at: at(7_200),
        provider_metadata: %{"customer_id" => "123"}
      })

    gsc =
      legacy!(%{
        provider: "google_search_console",
        account_id: account_id,
        user_id: user.id,
        access_token: MetricFlow.Vault.encrypt!("refreshable"),
        expires_at: at(60),
        provider_metadata: %{"site_url" => "https://example.com/"}
      })

    migrate!()

    assert [%Integration{} = merged] =
             Repo.all(from(i in Integration, where: i.account_id == ^account_id))

    assert merged.id == google
    assert merged.access_token == "refreshable"
    assert merged.refresh_token == "refresh"

    assert merged.provider_metadata == %{
             "customer_id" => "123",
             "site_url" => "https://example.com/"
           }

    refute Repo.get(Integration, gsc)
  end

  test "rows signed in as different Google users keep the usable login's token and scopes" do
    user = user_fixture()
    account_id = default_account_id(user)

    ga =
      legacy!(%{
        provider: "google_analytics",
        account_id: account_id,
        user_id: user.id,
        access_token: MetricFlow.Vault.encrypt!("work-access"),
        expires_at: at(60),
        granted_scopes: ["openid", "https://www.googleapis.com/auth/analytics.readonly"],
        provider_metadata: %{
          "email" => "me@work.example",
          "provider_user_id" => "work",
          "property_id" => "properties/1"
        },
        inserted_at: at(-7_200),
        updated_at: at(-7_200)
      })

    legacy!(%{
      provider: "google_business",
      account_id: account_id,
      user_id: user.id,
      access_token: MetricFlow.Vault.encrypt!("personal-access"),
      expires_at: at(3_600),
      granted_scopes: ["openid", "https://www.googleapis.com/auth/userinfo.email"],
      provider_metadata: %{"email" => "me@personal.example", "provider_user_id" => "personal"},
      inserted_at: at(-3_600),
      updated_at: at(-3_600)
    })

    migrate!()

    assert [%Integration{id: ^ga} = google] =
             Repo.all(from(i in Integration, where: i.account_id == ^account_id))

    assert google.access_token == "work-access"
    assert google.provider_metadata["email"] == "me@work.example"
    assert google.provider_metadata["property_id"] == "properties/1"

    assert Enum.sort(google.granted_scopes) ==
             ["https://www.googleapis.com/auth/analytics.readonly", "openid"]
  end
end
