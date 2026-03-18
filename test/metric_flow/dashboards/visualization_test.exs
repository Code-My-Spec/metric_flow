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
    test "creates a valid changeset when all required fields are provided" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "casts `name`, `user_id`, `vega_spec`, and `shareable` correctly into changeset changes" do
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

    test "returns an invalid changeset when `name` is absent" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :name)

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset when `user_id` is absent" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :user_id)

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{user_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns an invalid changeset when `vega_spec` is absent" do
      user = user_fixture()
      attrs = Map.delete(valid_attrs(user.id), :vega_spec)

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{vega_spec: ["can't be blank"]} = errors_on(changeset)
    end

    test "rejects an empty string for `name` (below minimum length of 1)" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: ""}

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "rejects a `name` longer than 255 characters" do
      user = user_fixture()
      long_name = String.duplicate("a", 256)
      attrs = %{valid_attrs(user.id) | name: long_name}

      changeset = Visualization.changeset(new_visualization(), attrs)

      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end

    test "accepts a `name` of exactly 1 character (minimum boundary)" do
      user = user_fixture()
      attrs = %{valid_attrs(user.id) | name: "A"}

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts a `name` of exactly 255 characters (maximum boundary)" do
      user = user_fixture()
      max_name = String.duplicate("a", 255)
      attrs = %{valid_attrs(user.id) | name: max_name}

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "defaults `shareable` to false when not provided in attrs" do
      user = user_fixture()
      attrs = valid_attrs(user.id)

      visualization = insert_visualization!(attrs)

      assert visualization.shareable == false
    end

    test "accepts `shareable: true` explicitly" do
      user = user_fixture()
      attrs = Map.put(valid_attrs(user.id), :shareable, true)

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
      assert get_change(changeset, :shareable) == true
    end

    test "accepts `shareable: false` explicitly" do
      user = user_fixture()
      attrs = Map.put(valid_attrs(user.id), :shareable, false)

      changeset = Visualization.changeset(new_visualization(), attrs)

      assert changeset.valid?
    end

    test "accepts any valid Elixir map for `vega_spec` (including empty map and nested maps)" do
      user = user_fixture()

      for spec <- [%{}, %{"mark" => "line"}, %{"nested" => %{"deep" => true}}] do
        attrs = %{valid_attrs(user.id) | vega_spec: spec}
        changeset = Visualization.changeset(new_visualization(), attrs)

        assert changeset.valid?, "expected vega_spec #{inspect(spec)} to be valid"
      end
    end

    test "triggers `assoc_constraint` error on insert when `user_id` references a non-existent user" do
      attrs = valid_attrs(-1)

      {:error, changeset} =
        new_visualization()
        |> Visualization.changeset(attrs)
        |> Repo.insert()

      assert %{user: ["does not exist"]} = errors_on(changeset)
    end

    test "produces a valid changeset when updating an existing visualization with a subset of fields" do
      user = user_fixture()
      visualization = insert_visualization!(valid_attrs(user.id))

      update_attrs = %{name: "Updated Chart Name"}
      changeset = Visualization.changeset(visualization, update_attrs)

      assert changeset.valid?
      assert get_change(changeset, :name) == "Updated Chart Name"
    end

    test "preserves existing field values on the changeset struct when only a subset of attributes are updated" do
      user = user_fixture()
      visualization = insert_visualization!(valid_attrs(user.id))

      update_attrs = %{shareable: true}
      changeset = Visualization.changeset(visualization, update_attrs)

      assert changeset.data.name == "Monthly Revenue"
      assert changeset.data.user_id == user.id
      assert changeset.data.vega_spec == valid_vega_spec()
    end

    test "handles an empty attributes map gracefully without marking the changeset invalid" do
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
    test "returns `true` when `shareable` is `true`" do
      visualization = struct!(Visualization, shareable: true)

      assert Visualization.shareable?(visualization)
    end

    test "returns `false` when `shareable` is `false`" do
      visualization = struct!(Visualization, shareable: false)

      refute Visualization.shareable?(visualization)
    end

    test "returns `false` when `shareable` is `nil` (field unset)" do
      visualization = struct!(Visualization, shareable: nil)

      refute Visualization.shareable?(visualization)
    end

    test "returns the correct result when the struct also has a populated `vega_spec` map" do
      visualization = struct!(Visualization, shareable: true, vega_spec: valid_vega_spec())

      assert Visualization.shareable?(visualization)
    end

    test "returns `false` for a visualization with no dashboard associations loaded" do
      visualization = struct!(Visualization, shareable: false)

      refute Visualization.shareable?(visualization)
    end
  end
end
