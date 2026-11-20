defmodule MetricFlowWeb.HelpLive.AccountOriginationTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts.{Account, AccountMember}
  alias MetricFlow.Repo

  defp agency_fixture(user) do
    account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "Test Agency",
        slug: "agency-#{System.unique_integer([:positive])}",
        type: "agency",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: :owner
    })
    |> Repo.insert!()

    account
  end

  describe "mount" do
    test "renders the four origination sections with the page heading", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/help/account-origination")

      assert html =~ "How Account Origination Works"
      assert html =~ "Self-registration"
      assert html =~ "Domain auto-enrollment"
      assert html =~ "Agency referral links"
      assert html =~ "Email invitations"
    end

    test "links to the agency Clients page so the reader can reach the referral control",
         %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/help/account-origination")

      doc = Floki.parse_document!(html)

      clients_links =
        doc
        |> Floki.find(
          ~s|main[data-role="help-account-origination-root"] a[href="/app/agency/clients"]|
        )

      assert length(clients_links) >= 1,
             "Expected a visible link to /app/agency/clients inside the help page root"
    end
  end

  describe "Anderson BI layout" do
    test "wraps content in a help-account-origination root that caps width and blocks sideways scroll",
         %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/help/account-origination")

      [{_tag, attrs, _children}] =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|main[data-role="help-account-origination-root"]|)

      class = attrs |> Enum.into(%{}) |> Map.fetch!("class")

      assert class =~ "overflow-x-hidden",
             ~s|Expected help-account-origination root to carry overflow-x-hidden; got class="#{class}"|

      assert class =~ ~r/\bmax-w-/,
             ~s|Expected help-account-origination root to cap its width with a max-w-* class; got class="#{class}"|
    end

    test "renders exactly one h1 inside the help-account-origination root", %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/help/account-origination")

      headings =
        html
        |> Floki.parse_document!()
        |> Floki.find(~s|main[data-role="help-account-origination-root"] h1|)

      assert length(headings) == 1,
             "Expected one h1 inside the help-account-origination root, got #{length(headings)}"
    end

    test "uses only theme tokens for colours (no hard-coded hex or tailwind palette shades)",
         %{conn: conn} do
      user = user_fixture()
      _account = agency_fixture(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, "/app/help/account-origination")

      doc = Floki.parse_document!(html)

      [{_tag, _attrs, children}] =
        Floki.find(doc, ~s|main[data-role="help-account-origination-root"]|)

      root_html = Floki.raw_html({"main", [], children})

      refute root_html =~ ~r/\bprose\b/,
             "Expected no `prose` classes inside the help root; Anderson BI uses only its own text tokens"

      refute root_html =~ ~r/#[0-9A-Fa-f]{3,6}\b/,
             "Expected no hard-coded hex colours inside the help root"

      refute root_html =~
               ~r/\b(?:bg|text|border)-(?:slate|gray|zinc|neutral-\d|stone|red|orange|amber|yellow|lime|green|emerald|teal|cyan|sky|blue|indigo|violet|purple|fuchsia|pink|rose)-\d{2,3}\b/,
             "Expected no raw tailwind palette shades inside the help root; use base-*, primary, accent, error tokens instead"
    end
  end
end
