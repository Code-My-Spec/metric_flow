defmodule MetricFlow.Repo.Migrations.AddLastActiveAtToAccountMembers do
  use Ecto.Migration

  def change do
    alter table(:account_members) do
      add :last_active_at, :utc_datetime
    end

    execute(
      "UPDATE account_members SET last_active_at = updated_at",
      ""
    )
  end
end
