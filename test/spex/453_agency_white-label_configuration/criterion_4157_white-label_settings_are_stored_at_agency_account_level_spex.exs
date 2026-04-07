defmodule MetricFlowSpex.WhiteLabelSettingsStoredAtAgencyAccountLevelSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "White-label settings are stored at agency account level" do
    scenario "saved white-label settings persist after remounting the LiveView (page refresh)" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to account settings and saves white-label branding", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://cdn.agencytest.com/stored-logo.png",
          subdomain: "storedagency",
          primary_color: "#AA1122",
          secondary_color: "#334455"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the owner remounts the settings page (simulating a page refresh)", context do
        refreshed_conn = recycle(context.owner_conn)
        {:ok, refreshed_view, _html} = live(refreshed_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :refreshed_view, refreshed_view)}
      end

      then_ "the saved logo URL is pre-filled in the form", context do
        assert render(context.refreshed_view) =~ "https://cdn.agencytest.com/stored-logo.png"
        :ok
      end

      then_ "the saved subdomain is pre-filled in the form", context do
        assert render(context.refreshed_view) =~ "storedagency"
        :ok
      end

      then_ "the saved primary color is pre-filled in the form", context do
        assert render(context.refreshed_view) =~ "#AA1122"
        :ok
      end

      then_ "the saved secondary color is pre-filled in the form", context do
        assert render(context.refreshed_view) =~ "#334455"
        :ok
      end
    end

    scenario "white-label settings saved by owner are visible to another admin in the same agency account" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as an admin of the agency account", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "admin"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the owner saves white-label settings", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://agency.example.com/shared-logo.svg",
          subdomain: "sharedagency",
          primary_color: "#112233",
          secondary_color: "#AABBCC"
        })
        |> render_submit()

        {:ok, context}
      end

      when_ "the second user logs in and navigates to account settings", context do
        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: context.second_user_email,
            password: context.second_user_password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        admin_conn = recycle(logged_in_conn)
        {:ok, admin_view, _html} = live(admin_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :admin_view, admin_view)}
      end

      then_ "the second user sees the White-Label Branding section", context do
        assert render(context.admin_view) =~ "White-Label Branding"
        :ok
      end

      then_ "the second user sees the owner's saved logo URL", context do
        assert render(context.admin_view) =~ "https://agency.example.com/shared-logo.svg"
        :ok
      end

      then_ "the second user sees the owner's saved subdomain", context do
        assert render(context.admin_view) =~ "sharedagency"
        :ok
      end

      then_ "the second user sees the owner's saved primary color", context do
        assert render(context.admin_view) =~ "#112233"
        :ok
      end

      then_ "the second user sees the owner's saved secondary color", context do
        assert render(context.admin_view) =~ "#AABBCC"
        :ok
      end
    end

    scenario "white-label settings from one agency account are not visible to users of a different account" do
      given_ :user_logged_in_as_owner

      when_ "the owner saves white-label settings for their agency", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/settings")

        view
        |> form("#white-label-form", white_label: %{
          logo_url: "https://owner-agency.example.com/private-logo.png",
          subdomain: "owneragency",
          primary_color: "#FF0000",
          secondary_color: "#00FF00"
        })
        |> render_submit()

        {:ok, context}
      end

      given_ "a separate user registers their own independent account", context do
        email = "separate#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        {:ok, reg_view, _html} = live(build_conn(), "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Separate Agency"
        })
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, build_conn())
        separate_conn = recycle(logged_in_conn)
        {:ok, Map.put(context, :separate_conn, separate_conn)}
      end

      when_ "the separate user navigates to their account settings", context do
        {:ok, separate_view, _html} = live(context.separate_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :separate_view, separate_view)}
      end

      then_ "the separate user does not see the first owner's logo URL", context do
        refute render(context.separate_view) =~ "https://owner-agency.example.com/private-logo.png"
        :ok
      end

      then_ "the separate user does not see the first owner's subdomain", context do
        refute render(context.separate_view) =~ "owneragency"
        :ok
      end
    end
  end
end
