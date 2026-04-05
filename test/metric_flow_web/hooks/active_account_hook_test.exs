defmodule MetricFlowWeb.Hooks.ActiveAccountHookTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlowWeb.Hooks.ActiveAccountHook
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # on_mount/4
  # ---------------------------------------------------------------------------

  describe "on_mount/4" do
    test "assigns active_account_name from the user's primary account" do
      user = user_fixture()
      scope = Scope.for_user(user)
      account = account_with_member_fixture(user, :member)

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, current_scope: scope}
      }

      {:cont, socket} = ActiveAccountHook.on_mount(:load_active_account, %{}, %{}, socket)

      assert socket.assigns.active_account_name == account.name
    end

    test "assigns nil when no current_scope is present" do
      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, current_scope: nil}
      }

      {:cont, socket} = ActiveAccountHook.on_mount(:load_active_account, %{}, %{}, socket)

      assert socket.assigns.active_account_name == nil
    end

    test "assigns nil when user has no accounts" do
      user = user_fixture()
      scope = Scope.for_user(user)

      socket = %Phoenix.LiveView.Socket{
        assigns: %{__changed__: %{}, current_scope: scope}
      }

      {:cont, socket} = ActiveAccountHook.on_mount(:load_active_account, %{}, %{}, socket)

      assert socket.assigns.active_account_name == nil
    end
  end

  # ---------------------------------------------------------------------------
  # primary_account/1
  # ---------------------------------------------------------------------------

  describe "primary_account/1" do
    test "returns the first account from a non-empty list" do
      first = %{name: "First Account"}
      second = %{name: "Second Account"}

      assert ActiveAccountHook.primary_account([first, second]) == first
    end

    test "returns nil for an empty list" do
      assert ActiveAccountHook.primary_account([]) == nil
    end
  end

  # ---------------------------------------------------------------------------
  # primary_account/2
  # ---------------------------------------------------------------------------

  describe "primary_account/2" do
    test "returns the account originated by the user when present" do
      user = user_fixture()

      originated = %{name: "My Account", originator_user_id: user.id}
      other = %{name: "Other Account", originator_user_id: user.id + 999}

      assert ActiveAccountHook.primary_account([other, originated], user) == originated
    end

    test "falls back to first account when user did not originate any" do
      user = user_fixture()

      first = %{name: "First", originator_user_id: user.id + 100}
      second = %{name: "Second", originator_user_id: user.id + 200}

      assert ActiveAccountHook.primary_account([first, second], user) == first
    end

    test "returns nil for an empty list" do
      user = user_fixture()

      assert ActiveAccountHook.primary_account([], user) == nil
    end
  end
end
