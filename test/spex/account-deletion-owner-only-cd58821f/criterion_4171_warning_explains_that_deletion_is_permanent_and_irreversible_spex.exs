defmodule MetricFlowSpex.WarningExplainsThatDeletionIsPermanentAndIrreversibleSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Warning explains that deletion is permanent and irreversible" do
    scenario "owner sees permanent deletion warning on settings page" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the delete section contains a warning about permanent deletion", context do
        delete_section = element(context.view, "[data-role='delete-account']")
        html = render(delete_section)
        assert html =~ "permanent"
        :ok
      end

      then_ "the delete section contains a warning that deletion is irreversible", context do
        delete_section = element(context.view, "[data-role='delete-account']")
        html = render(delete_section)
        assert html =~ "irreversible"
        :ok
      end
    end

    scenario "warning is visible before the user interacts with the delete form" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings without any interaction", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the permanent deletion warning is rendered in the danger zone on page load", context do
        assert has_element?(context.view, "[data-role='delete-account']")
        delete_section = element(context.view, "[data-role='delete-account']")
        html = render(delete_section)
        assert html =~ "permanent"
        assert html =~ "irreversible"
        :ok
      end
    end
  end
end
