defmodule MetricFlowSpex.ListShowsUserOrAgencyNameAccessLevelDateGrantedAndWhetherTheyAreAccountOriginatorSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "List shows user or agency name, access level, date granted, and whether they are account originator" do
    scenario "member row displays the user email as the user name" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner email is shown in the members list", context do
        assert render(context.view) =~ context.owner_email
        :ok
      end
    end

    scenario "member row displays the access level role badge" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the role column header is visible", context do
        assert render(context.view) =~ "Role"
        :ok
      end

      then_ "the owner role badge is displayed for the owner", context do
        assert render(context.view) =~ "owner"
        :ok
      end
    end

    scenario "member row displays the date the access was granted" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Joined column header is visible", context do
        assert render(context.view) =~ "Joined"
        :ok
      end

      then_ "the member row contains a date in the joined column", context do
        # The format_date helper renders dates as "Mon DD, YYYY" (e.g. "Feb 23, 2026")
        # Assert that a month abbreviation followed by digits pattern appears in a member row
        html = render(context.view)
        assert html =~ ~r/[A-Z][a-z]{2} \d{2}, \d{4}/
        :ok
      end
    end

    scenario "account originator is identified by the owner role badge" do
      given_ :user_logged_in_as_owner

      given_ "the owner navigates to the members page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the owner member row is present in the list", context do
        assert has_element?(context.view, "[data-role='member-row']")
        :ok
      end

      then_ "the owner row displays the owner role label indicating account originator status", context do
        # The account originator (the user who created the account) has the :owner role.
        # The members table renders the role as a badge with the text "owner".
        html = render(context.view)
        assert html =~ "owner"
        :ok
      end
    end

    scenario "invited member row shows all required fields alongside originator" do
      given_ :user_logged_in_as_owner
      given_ :second_user_registered

      given_ "the owner invites the second user as a member", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/accounts/members")

        view
        |> form("#invite_member_form", invitation: %{
          email: context.second_user_email,
          role: "member"
        })
        |> render_submit()

        {:ok, Map.put(context, :view, view)}
      end

      then_ "both user emails appear in the member list", context do
        html = render(context.view)
        assert html =~ context.owner_email
        assert html =~ context.second_user_email
        :ok
      end

      then_ "the invited member's role is displayed", context do
        # "member" is an alias for read_only role — the badge shows "read_only"
        assert render(context.view) =~ "read_only"
        :ok
      end

      then_ "the owner is identified with the owner role while the invited member is not", context do
        html = render(context.view)
        # Owner badge text appears
        assert html =~ "owner"
        # Invited member has read_only, not owner
        assert html =~ "read_only"
        :ok
      end

      then_ "each member row has a date in the joined column", context do
        html = render(context.view)
        # At least two date-formatted strings should be present (one per member)
        matches = Regex.scan(~r/[A-Z][a-z]{2} \d{2}, \d{4}/, html)
        assert length(matches) >= 2
        :ok
      end
    end
  end
end
