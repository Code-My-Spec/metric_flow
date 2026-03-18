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
    test "returns a valid changeset when all required fields are present" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "defaults size to \"medium\" when size is omitted and the record is inserted" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :size)

      dv = insert_dashboard_visualization!(attrs)

      assert dv.size == "medium"
    end

    test "casts `dashboard_id` correctly into the changeset" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :dashboard_id) == dashboard.id
    end

    test "casts `visualization_id` correctly into the changeset" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(dashboard.id, visualization.id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :visualization_id) == visualization.id
    end

    test "casts `position` correctly into the changeset" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | position: 5}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :position) == 5
    end

    test "casts `size` correctly into the changeset" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "large"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert get_change(changeset, :size) == "large"
    end

    test "returns an invalid changeset when `dashboard_id` is missing" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :dashboard_id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{dashboard_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset when `visualization_id` is missing" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :visualization_id)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{visualization_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset when `position` is missing" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :position)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{position: ["can't be blank"]} = errors_on(changeset)
    end

    test "accepts size as optional (omitting it still produces a valid changeset)" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = Map.delete(valid_attrs(dashboard.id, visualization.id), :size)

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts 0 as a valid position value" do
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

    test "rejects negative integers for position" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | position: -1}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{position: [_]} = errors_on(changeset)
    end

    test "accepts \"small\" as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "small"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts \"medium\" as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "medium"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts \"large\" as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "large"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts \"full\" as a valid size value" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "full"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      assert changeset.valid?
    end

    test "rejects size values outside the permitted set (e.g. \"gigantic\")" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      attrs = %{valid_attrs(dashboard.id, visualization.id) | size: "gigantic"}

      changeset = DashboardVisualization.changeset(new_dashboard_visualization(), attrs)

      refute changeset.valid?
      assert %{size: [_]} = errors_on(changeset)
    end

    test "returns an association error on insert when `dashboard_id` does not reference an existing dashboard" do
      user = user_fixture()
      visualization = insert_visualization!(user.id)
      attrs = valid_attrs(-1, visualization.id)

      {:error, changeset} =
        new_dashboard_visualization()
        |> DashboardVisualization.changeset(attrs)
        |> Repo.insert()

      assert %{dashboard: ["does not exist"]} = errors_on(changeset)
    end

    test "returns an association error on insert when `visualization_id` does not reference an existing visualization" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      attrs = valid_attrs(dashboard.id, -1)

      {:error, changeset} =
        new_dashboard_visualization()
        |> DashboardVisualization.changeset(attrs)
        |> Repo.insert()

      assert %{visualization: ["does not exist"]} = errors_on(changeset)
    end

    test "returns a unique constraint error on insert when the same `{dashboard_id, visualization_id}` pair already exists" do
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

    test "returns a valid changeset for updating mutable fields (position, size) on an existing record" do
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

    test "preserves existing field values when only a subset of attributes is updated" do
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

    test "handles an empty attributes map gracefully when called on a persisted record" do
      user = user_fixture()
      dashboard = insert_dashboard!(user.id)
      visualization = insert_visualization!(user.id)
      dv = insert_dashboard_visualization!(valid_attrs(dashboard.id, visualization.id))

      changeset = DashboardVisualization.changeset(dv, %{})

      assert changeset.valid?
    end
  end
end
