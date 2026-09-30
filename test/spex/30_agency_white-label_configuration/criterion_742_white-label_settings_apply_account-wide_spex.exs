defmodule MetricFlowSpex.WhiteLabelSettingsApplyAccountWideSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  import MetricFlowSpex.SharedGivens

  spex "White-label settings apply account-wide", criterion: 742 do
    scenario "a second user under the same agency account sees the same white-label settings" do
      given_(:agency_owner_logged_in)

      given_ "the agency's white-label settings have been saved", context do
        subdomain = "agency742-#{System.unique_integer([:positive])}"
        agency_domain = "agency742domain-#{System.unique_integer([:positive])}.com"

        {:ok, settings_view, _html} = live(context.owner_conn, "/app/accounts/settings")

        settings_view
        |> form("#white-label-form",
          white_label: %{
            subdomain: subdomain,
            primary_color: "#FF5733",
            secondary_color: "#3498DB"
          }
        )
        |> render_submit()

        settings_view
        |> form("#auto-enrollment-form",
          auto_enrollment: %{domain: agency_domain, default_access_level: "admin"}
        )
        |> render_submit()

        member_email = "member742@#{agency_domain}"
        member_password = "SecurePassword123!"

        reg_conn = build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form",
          user: %{email: member_email, password: member_password, account_name: "Member 742"}
        )
        |> render_submit()

        {:ok, login_view, _html} = live(build_conn(), "/users/log-in")

        login_form =
          form(login_view, "#login_form_password",
            user: %{email: member_email, password: member_password, remember_me: true}
          )

        member_conn = login_form |> submit_form(build_conn()) |> recycle()

        {:ok, Map.merge(context, %{member_conn: member_conn, subdomain: subdomain})}
      end

      when_ "any other user under that agency account views the settings", context do
        {:ok, member_view, _html} = live(context.member_conn, "/app/accounts/settings")
        {:ok, Map.put(context, :member_view, member_view)}
      end

      then_ "the same white-label settings apply for them", context do
        html = render(context.member_view)
        assert html =~ context.subdomain
        assert html =~ "#FF5733"
        {:ok, context}
      end
    end
  end
end
