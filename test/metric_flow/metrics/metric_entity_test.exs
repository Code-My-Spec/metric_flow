defmodule MetricFlow.Metrics.MetricEntityTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Metrics.MetricEntity
  alias MetricFlow.Repo

  @attrs %{entity_id: "accounts/123/locations/456", display_name: "Downtown"}

  test "requires an owner and provider entity ID" do
    changeset = MetricEntity.changeset(%MetricEntity{}, %{})

    refute changeset.valid?
    assert Keyword.has_key?(changeset.errors, :user_id)
    assert Keyword.has_key?(changeset.errors, :entity_id)
  end

  test "defaults the provider and keeps the owner supplied by the caller" do
    changeset =
      MetricEntity.changeset(
        %MetricEntity{user_id: 42},
        Map.put(@attrs, :user_id, 99)
      )

    assert changeset.valid?
    assert Ecto.Changeset.get_field(changeset, :user_id) == 42
    assert Ecto.Changeset.get_field(changeset, :provider) == :google_business
    assert Ecto.Changeset.get_field(changeset, :metadata) == %{}
  end

  test "rejects duplicate entity IDs for the same owner and provider" do
    user = user_fixture()
    entity = %MetricEntity{user_id: user.id}

    assert {:ok, _} = entity |> MetricEntity.changeset(@attrs) |> Repo.insert()

    assert {:error, changeset} =
             entity
             |> MetricEntity.changeset(%{@attrs | display_name: "Renamed"})
             |> Repo.insert()

    assert Keyword.has_key?(changeset.errors, :user_id)
  end
end
