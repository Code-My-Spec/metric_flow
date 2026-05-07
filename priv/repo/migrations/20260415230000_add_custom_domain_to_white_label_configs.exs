defmodule MetricFlow.Repo.Migrations.AddCustomDomainToWhiteLabelConfigs do
  use Ecto.Migration

  def change do
    alter table(:white_label_configs) do
      add :custom_domain, :string
      add :custom_domain_verified_at, :utc_datetime
      add :subdomain_verified_at, :utc_datetime
    end

    create unique_index(:white_label_configs, [:custom_domain],
      where: "custom_domain IS NOT NULL",
      name: :white_label_configs_custom_domain_index
    )
  end
end
