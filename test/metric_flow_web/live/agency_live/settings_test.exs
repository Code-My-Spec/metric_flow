defmodule MetricFlowWeb.AgencyLive.SettingsTest do
  use MetricFlowTest.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MetricFlowTest.UsersFixtures
  import MetricFlowTest.AgenciesFixtures

  alias MetricFlow.Accounts.Account
  alias MetricFlow.Accounts.AccountMember
  alias MetricFlow.Agencies
  alias MetricFlow.Repo
  alias MetricFlow.Users.Scope

  # ---------------------------------------------------------------------------
  # Fixtures
  # ---------------------------------------------------------------------------

  defp unique_slug, do: "account-#{System.unique_integer([:positive])}"

  defp insert_account!(user, attrs) do
    defaults = %{
      name: "Test Agency",
      slug: unique_slug(),
      type: "team",
      originator_user_id: user.id
    }

    %Account{}
    |> Account.creation_changeset(Map.merge(defaults, attrs))
    |> Repo.insert!()
  end

  defp insert_member!(account, user, role) do
    %AccountMember{}
    |> AccountMember.changeset(%{
      account_id: account.id,
      user_id: user.id,
      role: role
    })
    |> Repo.insert!()
  end

  # Creates a team account with the given user as owner member.
  defp team_account_with_owner(user, attrs \\ %{}) do
    account = insert_account!(user, attrs)
    insert_member!(account, user, :owner)
    account
  end

  # Creates a personal account with the given user as the owner member.
  defp personal_account_with_owner(user) do
    account =
      %Account{}
      |> Account.creation_changeset(%{
        name: "#{user.email} Personal",
        slug: "personal-#{System.unique_integer([:positive])}",
        type: "personal",
        originator_user_id: user.id
      })
      |> Repo.insert!()

    insert_member!(account, user, :owner)
    account
  end

  # ---------------------------------------------------------------------------
  # describe "mount/3"
  # ---------------------------------------------------------------------------

  describe "mount/3" do
    test "renders the agency auto-enrollment section for team account owner", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='agency-auto-enrollment']")
    end

    test "renders the agency white-label section for team account owner", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='agency-white-label']")
    end

    test "renders the agency auto-enrollment section for team account admin", %{conn: conn} do
      owner = user_fixture()
      account = team_account_with_owner(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='agency-auto-enrollment']")
    end

    test "renders the agency white-label section for team account admin", %{conn: conn} do
      owner = user_fixture()
      account = team_account_with_owner(owner)
      admin_user = user_fixture()
      insert_member!(account, admin_user, :admin)
      conn = log_in_user(conn, admin_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='agency-white-label']")
    end

    test "hides agency sections for read_only members of team accounts", %{conn: conn} do
      owner = user_fixture()
      account = team_account_with_owner(owner)
      reader_user = user_fixture()
      insert_member!(account, reader_user, :read_only)
      conn = log_in_user(conn, reader_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='agency-auto-enrollment']")
      refute has_element?(lv, "[data-role='agency-white-label']")
    end

    test "hides agency sections for account_manager members of team accounts", %{conn: conn} do
      owner = user_fixture()
      account = team_account_with_owner(owner)
      manager_user = user_fixture()
      insert_member!(account, manager_user, :account_manager)
      conn = log_in_user(conn, manager_user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='agency-auto-enrollment']")
      refute has_element?(lv, "[data-role='agency-white-label']")
    end

    test "hides agency sections for personal accounts", %{conn: conn} do
      user = user_fixture()
      _account = personal_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='agency-auto-enrollment']")
      refute has_element?(lv, "[data-role='agency-white-label']")
    end

    test "pre-fills auto-enrollment domain input when a rule exists", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{email_domain: "myagency.com"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(
               lv,
               "[data-role='auto-enrollment-domain-input'][value='myagency.com']"
             )
    end

    test "pre-fills white-label subdomain input when a config exists", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      config = white_label_config_fixture(account.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "input[value='#{config.subdomain}']")
    end
  end

  # ---------------------------------------------------------------------------
  # describe "render/1"
  # ---------------------------------------------------------------------------

  describe "render/1" do
    test "shows Auto-Enrollment section header", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "Auto-Enrollment"
    end

    test "shows White-Label Branding section header", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, _lv, html} = live(conn, ~p"/accounts/settings")

      assert html =~ "White-Label Branding"
    end

    test "shows active badge and Disable button when an enabled rule exists", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, ".badge-success", "Active")
      assert has_element?(lv, "[data-role='disable-auto-enrollment']")
    end

    test "shows disabled badge and no Disable button when rule is disabled", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: false})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, ".badge-ghost", "Disabled")
      refute has_element?(lv, "[data-role='disable-auto-enrollment']")
    end

    test "does not show the Disable button when no auto-enrollment rule exists", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      refute has_element?(lv, "[data-role='disable-auto-enrollment']")
    end

    test "shows the Enable Auto-Enrollment submit button", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "form#auto-enrollment-form button[type='submit']", "Enable Auto-Enrollment")
    end

    test "shows the Save Branding submit button", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "form#white-label-form button[type='submit']", "Save Branding")
    end

    test "shows auto-enrollment domain input placeholder text when no rule exists", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "[data-role='auto-enrollment-domain-input'][placeholder='e.g., myagency.com']")
    end

    test "shows white-label logo URL input in the white-label form", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _config = white_label_config_fixture(account.id)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(lv, "form#white-label-form input[name='white_label[logo_url]']")
    end

    test "pre-fills white-label logo URL when config exists", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _config = white_label_config_fixture(account.id, %{logo_url: "https://example.com/logo.png"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      assert has_element?(
               lv,
               "input[name='white_label[logo_url]'][value='https://example.com/logo.png']"
             )
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event save_auto_enrollment"
  # ---------------------------------------------------------------------------

  describe "handle_event save_auto_enrollment" do
    test "shows Auto-enrollment enabled flash on successful form submission", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#auto-enrollment-form", %{
          "auto_enrollment" => %{
            "domain" => "myagency.com",
            "default_access_level" => "read_only"
          }
        })
        |> render_submit()

      assert html =~ "Auto-enrollment enabled"
    end

    test "creates a new auto-enrollment rule for the account on successful submission", %{
      conn: conn
    } do
      user = user_fixture()
      account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> form("form#auto-enrollment-form", %{
        "auto_enrollment" => %{
          "domain" => "newdomain.com",
          "default_access_level" => "read_only"
        }
      })
      |> render_submit()

      scope = Scope.for_user(user)
      rule = Agencies.get_auto_enrollment_rule(scope, account.id)
      assert rule.email_domain == "newdomain.com"
    end

    test "shows an error flash when auto-enrollment domain is invalid", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#auto-enrollment-form", %{
          "auto_enrollment" => %{
            "domain" => "",
            "default_access_level" => "read_only"
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "updates an existing auto-enrollment rule on re-submission", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{email_domain: "old.com"})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#auto-enrollment-form", %{
          "auto_enrollment" => %{
            "domain" => "new.com",
            "default_access_level" => "read_only"
          }
        })
        |> render_submit()

      assert html =~ "Auto-enrollment enabled"
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event disable_auto_enrollment"
  # ---------------------------------------------------------------------------

  describe "handle_event disable_auto_enrollment" do
    test "shows Auto-enrollment disabled flash after clicking the Disable button", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> element("[data-role='disable-auto-enrollment']")
        |> render_click()

      assert html =~ "Auto-enrollment disabled"
    end

    test "hides the active badge after disabling auto-enrollment", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> element("[data-role='disable-auto-enrollment']")
      |> render_click()

      refute has_element?(lv, ".badge-success", "Active")
    end

    test "shows the disabled badge after disabling auto-enrollment", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> element("[data-role='disable-auto-enrollment']")
      |> render_click()

      assert has_element?(lv, ".badge-ghost", "Disabled")
    end

    test "removes the Disable button after disabling auto-enrollment", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> element("[data-role='disable-auto-enrollment']")
      |> render_click()

      refute has_element?(lv, "[data-role='disable-auto-enrollment']")
    end

    test "persists the disabled state to the database after clicking Disable", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _rule = auto_enrollment_rule_fixture(account.id, %{enabled: true})
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> element("[data-role='disable-auto-enrollment']")
      |> render_click()

      scope = Scope.for_user(user)
      rule = Agencies.get_auto_enrollment_rule(scope, account.id)
      assert rule.enabled == false
    end
  end

  # ---------------------------------------------------------------------------
  # describe "handle_event save_white_label"
  # ---------------------------------------------------------------------------

  describe "handle_event save_white_label" do
    test "shows White-label settings saved flash on successful form submission", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      unique = System.unique_integer([:positive])

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "myagency-#{unique}",
            "logo_url" => "https://example.com/logo.png",
            "primary_color" => "#FF5733",
            "secondary_color" => "#3498DB"
          }
        })
        |> render_submit()

      assert html =~ "White-label settings saved"
    end

    test "persists white-label config to the database on successful submission", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      unique = System.unique_integer([:positive])
      subdomain = "persist-#{unique}"

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      lv
      |> form("form#white-label-form", %{
        "white_label" => %{
          "subdomain" => subdomain,
          "logo_url" => "https://example.com/logo.png",
          "primary_color" => "#FF5733",
          "secondary_color" => "#3498DB"
        }
      })
      |> render_submit()

      scope = Scope.for_user(user)
      config = Agencies.get_white_label_config(scope, account.id)
      assert config.subdomain == subdomain
    end

    test "updates an existing white-label config on re-submission", %{conn: conn} do
      user = user_fixture()
      account = team_account_with_owner(user)
      _config = white_label_config_fixture(account.id)
      conn = log_in_user(conn, user)

      unique = System.unique_integer([:positive])
      new_subdomain = "updated-#{unique}"

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => new_subdomain,
            "logo_url" => "https://example.com/new-logo.png",
            "primary_color" => "#AABBCC",
            "secondary_color" => "#112233"
          }
        })
        |> render_submit()

      assert html =~ "White-label settings saved"
    end

    test "shows an error when white-label subdomain is blank", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "",
            "logo_url" => "https://example.com/logo.png",
            "primary_color" => "#FF5733",
            "secondary_color" => "#3498DB"
          }
        })
        |> render_submit()

      assert html =~ "can&#39;t be blank"
    end

    test "shows an error when white-label primary color has invalid format", %{conn: conn} do
      user = user_fixture()
      _account = team_account_with_owner(user)
      conn = log_in_user(conn, user)

      unique = System.unique_integer([:positive])

      {:ok, lv, _html} = live(conn, ~p"/accounts/settings")

      html =
        lv
        |> form("form#white-label-form", %{
          "white_label" => %{
            "subdomain" => "valid-#{unique}",
            "logo_url" => "https://example.com/logo.png",
            "primary_color" => "not-a-color",
            "secondary_color" => "#3498DB"
          }
        })
        |> render_submit()

      assert html =~ "invalid"
    end
  end
end
