defmodule MetricFlow.Dashboards.DashboardVisualizationTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Dashboards.DashboardVisualization
  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp insert_dashboard!(user_id) do
    %Dashboard{}
    |> Dashboard.changeset(%{
      name: "Test Dashboard #{System.unique_integer([:positive])}",
      user_id: user_id
    })
    |> Repo.insert!()
  end

  defp insert_visualization!(user_id) do
    %Visualization{}
    |> Visualization.changeset(%{
      name: "Test Visualization #{System.unique_integer([:positive])}",
      user_id: user_id,
      vega_spec: %{"mark" => "bar"}
    })
    |> Repo.insert!()
  end

  defp valid_attrs(dashboard_id, visualization_id) do
    %{
      dashboard_id: dashboard_id,
      visualization_id: visualization_id,
      position: 0,
      size: "medium"
    }
  end

  defp new_dashboard_visualization do
    struct!(DashboardVisualization, [])
  end

  defp insert_dashboard_visualization!(attrs) do
    new_dashboard_visualization()
    |> DashboardVisualization.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields present" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "creates valid changeset when size is omitted, defaulting to medium" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :size)

      dv = insert_dashboard_visualization!(attrs)

      assert dv.size == "medium"
    end

    test "casts dashboard_id attribute correctly" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :dashboard_id) == dashboard.id
    end

    test "casts visualization_id attribute correctly" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :visualization_id) == visualization.id
    end

    test "casts position attribute correctly" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | position: 5}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :position) == 5
    end

    test "casts size attribute correctly" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "large"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :size) == "large"
    end

    test "validates dashboard_id is required" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :dashboard_id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{dashboard_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates visualization_id is required" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :visualization_id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{visualization_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates position is required" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :position)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{position: ["can't be blank"]} = errors_on(changeset)
    end

    test "allows size to be omitted (optional field)" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :size)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts position of 0 as valid" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | position: 0}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :position) == 0
    end

    test "accepts positive integers for position" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | position: 99}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :position) == 99
    end

    test "rejects negative values for position" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | position: -1}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{position: [_]} = errors_on(changeset)
    end

    test "accepts small as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "small"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts medium as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "medium"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts large as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "large"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts full as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "full"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "rejects size values outside the permitted set" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "gigantic"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{size: [_]} = errors_on(changeset)
    end

    test "validates dashboard association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(-1, visualization.id)

      {:error, changeset} =
        new_dashboard_visualization()
        |> DashboardVisualization.changeset(attrs)
        |> Repo.insert()

      assert %{dashboard: ["does not exist"]} = errors_on(changeset)
    end

    test "validates visualization association exists (assoc_constraint triggers on insert)" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      attrs = valid_attrs(dashboard.id, -1)

      {:error, changeset} =
        new_dashboard_visualization()
        |> DashboardVisualization.changeset(attrs)
        |> Repo.insert()

      assert %{visualization: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces unique constraint on dashboard_id and visualization_id (unique_constraint triggers on insert)" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      _first = insert_dashboard_visualization!(attrs)

      {:error, changeset} =
        new_dashboard_visualization()
        |> DashboardVisualization.changeset(%{attrs | position: 1})
        |> Repo.insert()

      assert %{dashboard_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "creates valid changeset for updating an existing record" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      dv = insert_dashboard_visualization!(valid_attrs(dashboard.id, visualization.id))

      update_attrs = %{position: 3, size: "large"}
      changeset = DashboardVisualization.changeset(dv, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :position) == 3
      assert get_change(changeset, :size) == "large"
    end

    test "preserves existing fields when updating a subset of attributes" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      dv = insert_dashboard_visualization!(valid_attrs(dashboard.id, visualization.id))

      update_attrs = %{position: 2}
      changeset = DashboardVisualization.changeset(dv, update_attrs)

      assert changeset.data.dashboard_id == dashboard.id
      assert changeset.data.visualization_id == visualization.id
      assert changeset.data.size == "medium"
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      dv = insert_dashboard_visualization!(valid_attrs(dashboard.id, visualization.id))

      changeset = DashboardVisualization.changeset(dv, %{})

      assert changeset.valid?
    end
  end
end
