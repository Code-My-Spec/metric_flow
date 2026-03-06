defmodule MetricFlow.Dashboards.VisualizationsRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Visualization
  alias MetricFlow.Dashboards.VisualizationsRepository
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp user_with_scope do
    user = user_fixture()
    scope = Scope.for_user(user)
    {user, scope}
  end

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

  defp valid_visualization_attrs(user_id, overrides \\ %{}) do
    Map.merge(
      %{
        name: "Test Visualization",
        user_id: user_id,
        vega_spec: valid_vega_spec()
      },
      overrides
    )
  end

  defp insert_visualization!(user_id, overrides \\ %{}) do
    attrs = valid_visualization_attrs(user_id, overrides)

    %Visualization{}
    |> Visualization.changeset(attrs)
    |> Repo.insert!()
  end

  # ---------------------------------------------------------------------------
  # list_visualizations/1
  # ---------------------------------------------------------------------------

  describe "list_visualizations/1" do
    test "returns all visualizations for scoped user" do
      {user, scope} = user_with_scope()
      insert_visualization!(user.id)
      insert_visualization!(user.id, %{name: "Second Viz"})

      results = VisualizationsRepository.list_visualizations(scope)

      assert length(results) == 2
    end

    test "returns empty list when user has no visualizations" do
      {_user, scope} = user_with_scope()

      assert VisualizationsRepository.list_visualizations(scope) == []
    end

    test "does not return visualizations belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      insert_visualization!(user.id)
      insert_visualization!(other_user.id)

      results = VisualizationsRepository.list_visualizations(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "orders by most recently created first" do
      {user, scope} = user_with_scope()

      older = insert_visualization!(user.id, %{name: "Older Viz"})
      newer = insert_visualization!(user.id, %{name: "Newer Viz"})

      results = VisualizationsRepository.list_visualizations(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end
  end

  # ---------------------------------------------------------------------------
  # get_visualization/2
  # ---------------------------------------------------------------------------

  describe "get_visualization/2" do
    test "returns ok tuple with visualization when found" do
      {user, scope} = user_with_scope()
      viz = insert_visualization!(user.id)

      assert {:ok, result} = VisualizationsRepository.get_visualization(scope, viz.id)
      assert result.id == viz.id
    end

    test "returns error tuple with :not_found when visualization doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = VisualizationsRepository.get_visualization(scope, -1)
    end

    test "returns error tuple with :not_found when visualization belongs to different user" do
      {other_user, _other_scope} = user_with_scope()
      viz = insert_visualization!(other_user.id)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = VisualizationsRepository.get_visualization(scope, viz.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_visualization/2
  # ---------------------------------------------------------------------------

  describe "create_visualization/2" do
    test "creates visualization with valid attributes" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_visualization_attrs(user.id), :user_id)

      assert {:ok, viz} = VisualizationsRepository.create_visualization(scope, attrs)
      assert viz.id != nil
      assert viz.name == "Test Visualization"
    end

    test "sets user_id from scope automatically" do
      {user, scope} = user_with_scope()
      attrs = Map.delete(valid_visualization_attrs(user.id), :user_id)

      assert {:ok, viz} = VisualizationsRepository.create_visualization(scope, attrs)
      assert viz.user_id == user.id
    end

    test "returns error changeset when name is missing" do
      {user, scope} = user_with_scope()
      attrs = valid_visualization_attrs(user.id) |> Map.delete(:user_id) |> Map.delete(:name)

      assert {:error, changeset} = VisualizationsRepository.create_visualization(scope, attrs)
      refute changeset.valid?
      assert %{name: [_ | _]} = errors_on(changeset)
    end

    test "returns error changeset when vega_spec is missing" do
      {user, scope} = user_with_scope()

      attrs =
        valid_visualization_attrs(user.id) |> Map.delete(:user_id) |> Map.delete(:vega_spec)

      assert {:error, changeset} = VisualizationsRepository.create_visualization(scope, attrs)
      refute changeset.valid?
      assert %{vega_spec: [_ | _]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # update_visualization/2
  # ---------------------------------------------------------------------------

  describe "update_visualization/2" do
    test "updates visualization name" do
      {user, _scope} = user_with_scope()
      viz = insert_visualization!(user.id)

      assert {:ok, updated} = VisualizationsRepository.update_visualization(viz, %{name: "New Name"})
      assert updated.name == "New Name"
    end

    test "updates visualization vega_spec" do
      {user, _scope} = user_with_scope()
      viz = insert_visualization!(user.id)

      new_spec = %{"$schema" => "https://vega.github.io/schema/vega-lite/v5.json", "mark" => "line"}

      assert {:ok, updated} =
               VisualizationsRepository.update_visualization(viz, %{vega_spec: new_spec})

      assert updated.vega_spec == new_spec
    end

    test "returns error changeset for invalid attrs" do
      {user, _scope} = user_with_scope()
      viz = insert_visualization!(user.id)

      assert {:error, changeset} =
               VisualizationsRepository.update_visualization(viz, %{name: ""})

      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # delete_visualization/1
  # ---------------------------------------------------------------------------

  describe "delete_visualization/1" do
    test "deletes the visualization" do
      {user, scope} = user_with_scope()
      viz = insert_visualization!(user.id)

      assert {:ok, _} = VisualizationsRepository.delete_visualization(viz)

      assert {:error, :not_found} = VisualizationsRepository.get_visualization(scope, viz.id)
    end

    test "returns ok tuple with deleted visualization" do
      {user, _scope} = user_with_scope()
      viz = insert_visualization!(user.id)

      assert {:ok, deleted} = VisualizationsRepository.delete_visualization(viz)
      assert deleted.id == viz.id
    end
  end
end
