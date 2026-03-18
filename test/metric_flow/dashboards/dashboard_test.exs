defmodule MetricFlow.Dashboards.DashboardTest do
  use MetricFlowTest.DataCase, async: true

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
    test "returns a valid changeset when all required fields are present" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "casts name correctly" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :name) == "My Dashboard"
    end

    test "casts description correctly" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :description) == "A description of the dashboard"
    end

    test "casts user_id correctly" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :user_id) == user.id
    end

    test "casts built_in correctly when set to true" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | built_in: true}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert get_change(changeset, :built_in) == true
    end

    test "returns an invalid changeset and adds a name error when name is absent" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :name)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset and adds a user_id error when user_id is absent" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :user_id)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset when name is an empty string" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: ""}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "returns an invalid changeset when name exceeds 255 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: String.duplicate("a", 256)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "returns a valid changeset when name is exactly 1 character" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: "X"}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "returns a valid changeset when name is exactly 255 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: String.duplicate("a", 255)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "returns an invalid changeset when description exceeds 1000 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | description: String.duplicate("a", 1001)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      refute changeset.valid?
      assert %{description: [_]} = errors_on(changeset)
    end

    test "returns a valid changeset when description is exactly 1000 characters" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | description: String.duplicate("a", 1000)}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "returns a valid changeset when description is nil (optional field)" do
      user = user_fixture()
      attrs = Map.put(valid_attrs(user.id), :description, nil)

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
    end

    test "defaults built_in to false when omitted from attrs (enforced at the database level)" do
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

    test "accepts built_in false for user-created dashboards" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | built_in: false}

      changeset = Dashboard.changeset(new_dashboard(), attrs)

      assert changeset.valid?
      assert get_field(changeset, :built_in) == false
    end

    test "triggers the user assoc_constraint and surfaces \"does not exist\" error on insert with a non-existent user_id" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_dashboard()
        |> Dashboard.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "returns a valid changeset when updating an existing dashboard with a subset of fields" do
      user = user_fixture()
      dashboard = insert_dashboard!(valid_attrs(user.id))

      update_attrs = %{name: "Updated Dashboard"}
      changeset = Dashboard.changeset(dashboard, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Updated Dashboard"
    end

    test "preserves existing field values on the changeset data when only one field is updated" do
      user = user_fixture()
      dashboard = insert_dashboard!(valid_attrs(user.id))

      update_attrs = %{description: "New description"}
      changeset = Dashboard.changeset(dashboard, update_attrs)

      assert changeset.data.name == "My Dashboard"
      assert changeset.data.user_id == user.id
      assert changeset.data.built_in == false
    end

    test "returns a valid changeset when attrs is an empty map and the struct already has required fields" do
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

    test "returns false for a persisted dashboard that was inserted without explicitly setting built_in (default false)" do
      user = user_fixture()
      dashboard = insert_dashboard!(Map.delete(valid_attrs(user.id), :built_in))

      refute Dashboard.built_in?(dashboard)
    end
  end
end
