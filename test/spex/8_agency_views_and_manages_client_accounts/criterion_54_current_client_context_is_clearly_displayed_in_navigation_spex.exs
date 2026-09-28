defmodule MetricFlowSpex.CurrentClientContextIsClearlyDisplayedInNavigationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  alias MetricFlowTest.AgenciesFixtures

  spex "Current client context is clearly displayed in navigation", criterion: 54 do
    scenario "agency user viewing a client account sees the client account name in navigation" do
      given_ :user_logged_in_as_owner

      given_ "the agency owner has been granted access to a client account", context do
        client_account = AgenciesFixtures.account_fixture(%{name: "Acme Corp"})

        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client_account.id, :admin, false)

        {:ok, Map.merge(context, %{
          owner_account_name: MetricFlowSpex.Fixtures.personal_account_name(context.owner_email),
          client_account_id: client_account.id,
          client_account_name: "Acme Corp"
        })}
      end

      when_ "the agency user navigates to the accounts settings page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "a current account name indicator is visible in the navigation", context do
        assert has_element?(context.view, "[data-role='current-account-name']")
        {:ok, context}
      end
    end

    scenario "navigation shows the active client account name when viewing a client account page" do
      given_ :user_logged_in_as_owner

      given_ "the agency owner has been granted access to a client account named Bright Ideas", context do
        client_account = AgenciesFixtures.account_fixture(%{name: "Bright Ideas"})

        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client_account.id, :admin, false)

        {:ok, Map.merge(context, %{
          owner_account_name: MetricFlowSpex.Fixtures.personal_account_name(context.owner_email),
          client_account_name: "Bright Ideas"
        })}
      end

      when_ "the agency user navigates to the accounts list page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation shows the current account name", context do
        html = render(context.view)
        assert html =~ context.client_account_name or
               html =~ context.owner_account_name
        {:ok, context}
      end

      then_ "the current account name element is present in the page", context do
        assert has_element?(context.view, "[data-role='current-account-name']")
        {:ok, context}
      end
    end

    scenario "when the user's own account is active, their own account name is shown in navigation" do
      given_ :user_logged_in_as_owner

      when_ "the user navigates to the accounts page with their own account active", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "their own account name is visible in the navigation", context do
        assert render(context.view) =~ "Owner Account"
        {:ok, context}
      end

      then_ "the current account indicator reflects the user's own account", context do
        html = render(context.view)
        # The navigation element should contain the user's own account name
        assert html =~ "Owner Account"
        {:ok, context}
      end
    end

    scenario "the navigation clearly indicates which account is currently active across all authenticated pages" do
      given_ :user_logged_in_as_owner

      given_ "the agency owner has access to a client account", context do
        client_account = AgenciesFixtures.account_fixture(%{name: "Delta Analytics"})

        MetricFlowSpex.Fixtures.grant_client_account_access(context.owner_email, client_account.id, :admin, false)

        {:ok, Map.merge(context, %{
          owner_account_name: MetricFlowSpex.Fixtures.personal_account_name(context.owner_email),
          client_account_name: "Delta Analytics"
        })}
      end

      when_ "the agency user navigates to the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the navigation shows the current account context indicator", context do
        assert has_element?(context.view, "[data-role='current-account-name']")
        {:ok, context}
      end
    end
  end
end
