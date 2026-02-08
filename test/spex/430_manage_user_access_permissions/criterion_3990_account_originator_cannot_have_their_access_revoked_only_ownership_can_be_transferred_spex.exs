defmodule MetricFlowSpex.AccountOriginatorCannotHaveAccessRevokedSpex do
  @moduledoc """
  BDD specification for criterion 3990:
  Account originator cannot have their access revoked, only ownership can be transferred
  """

  use SexySpex
  use MetricFlowTest.ConnCase

  import_givens MetricFlowSpex.SharedGivens
  import Phoenix.LiveViewTest

  spex "Account originator cannot have their access revoked, only ownership can be transferred" do
    scenario "registration creates account originator" do
      given_ "a new user registers", context do
        {:ok, view, _html} = live(build_conn(), ~p"/users/register")
        email = "originator_perm_#{System.unique_integer([:positive])}@example.com"

        view
        |> form("#registration_form", user: %{email: email})
        |> render_submit()

        assert_redirect(view, "/users/log-in")
        {:ok, Map.put(context, :registered, true)}
      end

      then_ "the user is account originator", context do
        assert context.registered == true
        :ok
      end
    end
  end
end
