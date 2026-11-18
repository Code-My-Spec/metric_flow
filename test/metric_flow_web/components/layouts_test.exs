defmodule MetricFlowWeb.LayoutsTest do
  use MetricFlowTest.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Integrations.Integration
  alias MetricFlow.Repo

  defp insert_integration!(user) do
    %Integration{}
    |> Integration.changeset(%{
      user_id: user.id,
      account_id: MetricFlowTest.UsersFixtures.default_account_id(user.id),
      provider: :google_analytics,
      access_token: "access-token-#{System.unique_integer([:positive])}",
      expires_at: DateTime.add(DateTime.utc_now(), 3_600, :second),
      granted_scopes: [],
      provider_metadata: %{}
    })
    |> Repo.insert!()
  end

  describe "browser tab title suffix" do
    test "ends with the Anderson BI brand, not leftover Phoenix scaffold text", %{conn: conn} do
      user = user_fixture()
      insert_integration!(user)
      conn = log_in_user(conn, user)

      capture_log(fn ->
        {:ok, _lv, html} = live(conn, ~p"/app/dashboards")

        refute html =~ "Phoenix Framework"
        assert html =~ "· Anderson BI"
      end)
    end
  end
end
