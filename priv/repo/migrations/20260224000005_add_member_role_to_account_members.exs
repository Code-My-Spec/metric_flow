defmodule MetricFlow.Repo.Migrations.AddMemberRoleToAccountMembers do
  use Ecto.Migration

  def up do
    # Add :member as a valid role — the role field is stored as a plain string
    # so no ALTER TYPE is needed; we just allow the value at the application layer.
    # This migration is intentionally a no-op at the DB level because Ecto.Enum
    # stores enums as strings and Postgres does not enforce the allowed values.
    :ok
  end

  def down do
    :ok
  end
end
