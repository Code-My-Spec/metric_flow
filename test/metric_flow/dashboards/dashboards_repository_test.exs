defmodule MetricFlow.Dashboards.DashboardsRepositoryTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Dashboards.Dashboard
  alias MetricFlow.Dashboards.DashboardsRepository
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

  defp dashboard_fixture(user, attrs \\ %{}) do
    {:ok, dashboard} =
      %Dashboard{}
      |> Dashboard.changeset(Map.merge(%{name: "Test Dashboard", user_id: user.id}, attrs))
      |> Repo.insert()

    dashboard
  end

  # ---------------------------------------------------------------------------
  # list_dashboards/1
  # ---------------------------------------------------------------------------

  describe "list_dashboards/1" do
    test "returns all dashboards for scoped user" do
      {user, scope} = user_with_scope()
      dashboard_fixture(user)
      dashboard_fixture(user, %{name: "Second Dashboard"})

      results = DashboardsRepository.list_dashboards(scope)

      assert length(results) == 2
    end

    test "returns empty list when user has no dashboards" do
      {_user, scope} = user_with_scope()

      assert DashboardsRepository.list_dashboards(scope) == []
    end

    test "does not return dashboards belonging to other users" do
      {user, scope} = user_with_scope()
      {other_user, _other_scope} = user_with_scope()

      dashboard_fixture(user)
      dashboard_fixture(other_user, %{name: "Other User Dashboard"})

      results = DashboardsRepository.list_dashboards(scope)

      assert length(results) == 1
      assert hd(results).user_id == user.id
    end

    test "orders by most recently created first" do
      {user, scope} = user_with_scope()

      older = dashboard_fixture(user, %{name: "Older Dashboard"})
      newer = dashboard_fixture(user, %{name: "Newer Dashboard"})

      results = DashboardsRepository.list_dashboards(scope)
      result_ids = Enum.map(results, & &1.id)

      assert result_ids == [newer.id, older.id]
    end
  end

  # ---------------------------------------------------------------------------
  # get_dashboard/2
  # ---------------------------------------------------------------------------

  describe "get_dashboard/2" do
    test "returns ok tuple with dashboard when found" do
      {user, scope} = user_with_scope()
      dashboard = dashboard_fixture(user)

      assert {:ok, result} = DashboardsRepository.get_dashboard(scope, dashboard.id)
      assert result.id == dashboard.id
    end

    test "returns error tuple with :not_found when dashboard doesn't exist" do
      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DashboardsRepository.get_dashboard(scope, -1)
    end

    test "returns error tuple with :not_found when dashboard belongs to different user" do
      {other_user, _other_scope} = user_with_scope()
      other_dashboard = dashboard_fixture(other_user)

      {_user, scope} = user_with_scope()

      assert {:error, :not_found} = DashboardsRepository.get_dashboard(scope, other_dashboard.id)
    end
  end

  # ---------------------------------------------------------------------------
  # create_dashboard/2
  # ---------------------------------------------------------------------------

  describe "create_dashboard/2" do
    test "creates dashboard with valid attributes" do
      {_user, scope} = user_with_scope()

      assert {:ok, dashboard} = DashboardsRepository.create_dashboard(scope, %{name: "New Dashboard"})
      assert dashboard.id != nil
      assert dashboard.name == "New Dashboard"
    end

    test "sets user_id from scope automatically" do
      {user, scope} = user_with_scope()

      assert {:ok, dashboard} = DashboardsRepository.create_dashboard(scope, %{name: "My Dashboard"})
      assert dashboard.user_id == user.id
    end

    test "returns error changeset when name is missing" do
      {_user, scope} = user_with_scope()

      assert {:error, changeset} = DashboardsRepository.create_dashboard(scope, %{})
      refute changeset.valid?
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "returns error changeset when name is too long" do
      {_user, scope} = user_with_scope()

      long_name = String.duplicate("a", 256)

      assert {:error, changeset} = DashboardsRepository.create_dashboard(scope, %{name: long_name})
      refute changeset.valid?
      assert %{name: [_]} = errors_on(changeset)
    end
  end

  # ---------------------------------------------------------------------------
  # update_dashboard/2
  # ---------------------------------------------------------------------------

  describe "update_dashboard/2" do
    test "updates dashboard name" do
      {user, _scope} = user_with_scope()
      dashboard = dashboard_fixture(user)

      assert {:ok, updated} = DashboardsRepository.update_dashboard(dashboard, %{name: "Updated Name"})
      assert updated.name == "Updated Name"
      assert updated.id == dashboard.id
    end

    test "returns error changeset for invalid attrs" do
      {user, _scope} = user_with_scope()
      dashboard = dashboard_fixture(user)

      assert {:error, changeset} = DashboardsRepository.update_dashboard(dashboard, %{name: ""})
      refute changeset.valid?
    end
  end

  # ---------------------------------------------------------------------------
  # delete_dashboard/1
  # ---------------------------------------------------------------------------

  describe "delete_dashboard/1" do
    test "deletes the dashboard" do
      {user, scope} = user_with_scope()
      dashboard = dashboard_fixture(user)

      assert {:ok, _deleted} = DashboardsRepository.delete_dashboard(dashboard)
      assert {:error, :not_found} = DashboardsRepository.get_dashboard(scope, dashboard.id)
    end

    test "returns ok tuple with deleted dashboard" do
      {user, _scope} = user_with_scope()
      dashboard = dashboard_fixture(user)

      assert {:ok, deleted} = DashboardsRepository.delete_dashboard(dashboard)
      assert deleted.id == dashboard.id
    end
  end
end
