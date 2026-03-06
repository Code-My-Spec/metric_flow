defmodule MetricFlow.Dashboards.VisualizationTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Repo

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp valid_vega_spec do
    %{
      "$schema" => "https://vega.github.io/schema/vega-lite/v5.json",
      "mark" => "bar",
      "encoding" => %{
        "x" => %{"field" => "category", "type" => "nominal"},
        "y" => %{"field" => "value", "type" => "quantitative"}
      }
    }
  end

  defp valid_attrs(user_id) do
    %{
      name: "Monthly Revenue",
      user_id: user_id,
      vega_spec: valid_vega_spec()
    }
  end

  defp new_visualization do
    struct!(Visualization, [])
  end

  defp insert_visualization!(attrs) do
    new_visualization()
    |> Visualization.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # changeset/2
  # ---------------------------------------------------------------------------

  describe "changeset/2" do
    test "creates valid changeset with all required fields provided" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "casts name, user_id, vega_spec, and shareable correctly" do
      user = user_fixture()
      spec = valid_vega_spec()

      attrs = %{
        name: "My Chart",
        user_id: user.id,
        vega_spec: spec,
        shareable: true
      }

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert get_change(changeset, :name) == "My Chart"
      assert get_change(changeset, :user_id) == user.id
      assert get_change(changeset, :vega_spec) == spec
      assert get_change(changeset, :shareable) == true
    end

    test "validates name is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :name)

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates user_id is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :user_id)

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "validates vega_spec is required" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :vega_spec)

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{vega_spec: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects name shorter than 1 character (empty string)" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: ""}

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "rejects name longer than 255 characters" do
      user = user_fixture()
      long_name = String.duplicate("a", 256)
      attrs = %{valid_attrs(user.id) | name: long_name}

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "accepts name at exactly 1 character (minimum boundary)" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: "A"}

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts name at exactly 255 characters (maximum boundary)" do
      user = user_fixture()
      max_name = String.duplicate("a", 255)
      attrs = %{valid_attrs(user.id) | name: max_name}

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "defaults shareable to false when not provided" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      visualization = insert_visualization!(attrs)

      assert visualization.shareable == false
    end

    test "accepts shareable set to true" do
      user = user_fixture()
      attrs = Map.put(valid_attrs(user.id), :shareable, true)

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :shareable) == true
    end

    test "accepts shareable set to false explicitly" do
      user = user_fixture()
      attrs = Map.put(valid_attrs(user.id), :shareable, false)

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts any valid map for vega_spec" do
      user = user_fixture()

      for spec <- [%{}, %{"mark" => "line"}, %{"nested" => %{"deep" => true}}] do
        attrs = %{valid_attrs(user.id) | vega_spec: spec}
        changeset = Visualization.changeset(new_visualization(), attrs)

        assert changeset.valid?, "expected vega_spec #{inspect(spec)} to be valid"
      end
    end

    test "validates user association exists (assoc_constraint triggers on insert)" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_visualization()
        |> Visualization.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "creates valid changeset for updating an existing visualization" do
      user = user_fixture()
      visualization = insert_visualization!(valid_attrs(user.id))

      update_attrs = %{name: "Updated Chart Name"}
      changeset = Visualization.changeset(visualization, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Updated Chart Name"
    end

    test "preserves existing fields when updating a subset of attributes" do
      user = user_fixture()
      visualization = insert_visualization!(valid_attrs(user.id))

      update_attrs = %{shareable: true}
      changeset = Visualization.changeset(visualization, update_attrs)

      assert changeset.data.name == "Monthly Revenue"
      assert changeset.data.user_id == user.id
      assert changeset.data.vega_spec == valid_vega_spec()
    end

    test "handles empty attributes map gracefully" do
      user = user_fixture()
      visualization = insert_visualization!(valid_attrs(user.id))

      changeset = Visualization.changeset(visualization, %{})

      assert changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # shareable?/1
  # ---------------------------------------------------------------------------

  describe "shareable?/1" do
    test "returns true when shareable is true" do
      visualization = struct!(Visualization, shareable: true)

      assert Visualization.shareable?(visualization)
    end

    test "returns false when shareable is false" do
      visualization = struct!(Visualization, shareable: false)

      refute Visualization.shareable?(visualization)
    end

    test "returns false when shareable is nil (unset)" do
      visualization = struct!(Visualization, shareable: nil)

      refute Visualization.shareable?(visualization)
    end

    test "works with a visualization that has a vega_spec map" do
      visualization = struct!(Visualization, shareable: true, vega_spec: valid_vega_spec())

      assert Visualization.shareable?(visualization)
    end

    test "works with a visualization that has no dashboard associations" do
      visualization = struct!(Visualization, shareable: false)

      refute Visualization.shareable?(visualization)
    end
  end
end
