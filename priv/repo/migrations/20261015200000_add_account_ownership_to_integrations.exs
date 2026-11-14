defmodule MetricFlow.Repo.Migrations.AddAccountOwnershipToIntegrations do
  use Ecto.Migration

  def up do
    alter table(:integrations) do
      add :account_id, references(:accounts, on_delete: :delete_all)
    end

    drop unique_index(:integrations, [:user_id, :provider])

    create unique_index(:integrations, [:user_id, :provider],
             name: :integrations_user_id_provider_index,
             where: "provider <> 'youtube'"
           )

    create unique_index(:integrations, [:account_id, :provider],
             name: :integrations_account_id_provider_index
           )

    create constraint(:integrations, :youtube_requires_account,
             check: "provider <> 'youtube' OR account_id IS NOT NULL"
           )
  end

  def down do
    drop constraint(:integrations, :youtube_requires_account)

    drop unique_index(:integrations, [:account_id, :provider],
           name: :integrations_account_id_provider_index
         )

    drop unique_index(:integrations, [:user_id, :provider])
    create unique_index(:integrations, [:user_id, :provider])

    alter table(:integrations) do
      remove :account_id
    end
  end
end
