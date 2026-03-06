defmodule MetricFlow.Dashboards.DashboardTest do
  use MetricFlowTest.DataCase, async: true

  import Ecto.Changeset, only: [get_change: 2, get_field: 2]
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_attrs(user_id) do
    %{
      name: "My Dashboard",
      description: "A description of the dashboard",
      user_id: user_id,
      built_in: false
    }
  end

  defp new_dashboard do
    struct!(Dashboard, [])
  end

  defp insert_dashboard!(attrs) do
    new_dashboard()
    |> Dashboard.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "casts name attribute correctly" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :name) == "My Dashboard"
    end

    test "casts description attribute correctly" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :description) == "A description of the dashboard"
    end

    test "casts user_id attribute correctly" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :user_id) == user.id
    end

    test "casts built_in attribute correctly" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | built_in: true}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :built_in) == true
    end

    test "validates name is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :name)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates user_id is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :user_id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects name shorter than 1 character (empty string)" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: ""}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "rejects name longer than 255 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: String.duplicate("a", 256)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "accepts name of exactly 1 character" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: "X"}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "accepts name of exactly 255 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: String.duplicate("a", 255)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "rejects description longer than 1000 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | description: String.duplicate("a", 1001)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{description: [_]} = errors_on(changeset)
    end

    test "accepts description of exactly 1000 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | description: String.duplicate("a", 1000)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "allows nil description as optional" do
      user = user_fixture()
      attrs = Map.put(valid_attrs(user.id), :description, nil)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "defaults built_in to false when not provided" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :built_in)

      dashboard = insert_dashboard!(attrs)

      assert dashboard.built_in == false
    end

    test "accepts built_in true for system dashboards" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | built_in: true}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :built_in) == true
    end

    test "accepts built_in false for user dashboards" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | built_in: false}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
      assert get_field(changeset, :built_in) == false
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_dashboard()
        |> Dashboard.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "creates valid changeset for updating an existing dashboard" do
      user = user_fixture()
      dashboard = insert_dashboard!(valid_attrs(user.id))

      update_attrs = %{name: "Updated Dashboard"}
      changeset = Dashboard.changeset(dashboard, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Updated Dashboard"
    end

    test "preserves existing fields when updating a subset of attributes" do
      user = user_fixture()
      dashboard = insert_dashboard!(valid_attrs(user.id))

      update_attrs = %{description: "New description"}
      changeset = Dashboard.changeset(dashboard, update_attrs)

      assert changeset.data.name == "My Dashboard"
      assert changeset.data.user_id == user.id
      assert changeset.data.built_in == false
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      dashboard = insert_dashboard!(valid_attrs(user.id))

      changeset = Dashboard.changeset(dashboard, %{})

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # built_in?/1
  # ---------------------------------------------------------------------------

  describe "built_in?/1" do
    test "returns true when built_in is true" do
      dashboard = struct!(Dashboard, built_in: true)

      assert Dashboard.built_in?(dashboard)
    end

    test "returns false when built_in is false" do
      dashboard = struct!(Dashboard, built_in: false)

      refute Dashboard.built_in?(dashboard)
    end

    test "returns false for a dashboard with the default built_in value" do
      user = user_fixture()
      dashboard = insert_dashboard!(Map.delete(valid_attrs(user.id), :built_in))

      refute Dashboard.built_in?(dashboard)
    end
  end
end
