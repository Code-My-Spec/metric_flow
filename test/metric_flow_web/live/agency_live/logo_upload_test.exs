defmodule MetricFlowWeb.AgencyLive.LogoUploadTest do
  use MetricFlowTest.ConnCase, async: false

  import Phoenix.LiveViewTest
  import MetricFlowTest.AgenciesFixtures
  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Agencies
  alias MetricFlow.Users.Scope

  setup %{conn: conn} do
    bucket = System.get_env("BUCKET_NAME")

    credentials =
      for key <- [:access_key_id, :secret_access_key],
          do: {key, Application.fetch_env(:ex_aws, key)}

    System.put_env("BUCKET_NAME", "test-branding")
    Application.put_env(:ex_aws, :access_key_id, "test-access-key")
    Application.put_env(:ex_aws, :secret_access_key, "test-secret-key")

    on_exit(fn ->
      if bucket, do: System.put_env("BUCKET_NAME", bucket), else: System.delete_env("BUCKET_NAME")

      for {key, original} <- credentials do
        case original do
          {:ok, value} -> Application.put_env(:ex_aws, key, value)
          :error -> Application.delete_env(:ex_aws, key)
        end
      end
    end)

    user = user_fixture()
    account = account_with_member_fixture(user, :owner)
    %{conn: log_in_user(conn, user), account: account, scope: Scope.for_user(user)}
  end

  for path <- ["/app/accounts/settings", "/app/agency/settings"] do
    @path path
    test "uploads and persists a logo only on save through #{@path}", %{
      conn: conn,
      account: account,
      scope: scope
    } do
      {:ok, view, _html} = live(conn, @path)

      upload =
        file_input(view, "#white-label-form", :logo, [
          %{
            name: "logo.svg",
            type: "image/svg+xml",
            content: ~s(<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"></svg>)
          }
        ])

      render_upload(upload, "logo.svg")
      assert has_element?(view, "#pending-logo-preview img")
      assert Agencies.get_white_label_config(scope, account.id) == nil

      view |> form("#white-label-form", white_label: %{subdomain: "UPPERCASE"}) |> render_submit()
      assert has_element?(view, "#pending-logo-preview img")
      assert Agencies.get_white_label_config(scope, account.id) == nil

      view
      |> form("#white-label-form",
        white_label: %{
          subdomain: "uploaded-#{account.id}",
          accent_color: "#123456"
        }
      )
      |> render_submit()

      config = Agencies.get_white_label_config(scope, account.id)

      assert String.starts_with?(
               config.logo_url,
               "https://fly.storage.tigris.dev/test-branding/logos/"
             )

      assert String.ends_with?(config.logo_url, ".svg")
      assert config.accent_color == "#123456"
      refute has_element?(view, "#pending-logo-preview")
    end
  end

  test "previews logo and accent edits without persisting them", %{
    conn: conn,
    account: account,
    scope: scope
  } do
    {:ok, view, _html} = live(conn, "/app/accounts/settings")

    view
    |> form("#white-label-form",
      white_label: %{logo_url: "https://example.com/new.svg", accent_color: "#123456"}
    )
    |> render_change()

    assert has_element?(view, "#branding-logo-url-preview[src='https://example.com/new.svg']")
    assert has_element?(view, "#branding-accent-preview[style='background-color: #123456']")
    assert Agencies.get_white_label_config(scope, account.id) == nil
  end

  test "reset discards the pending logo and unsaved colors", %{
    conn: conn,
    account: account,
    scope: scope
  } do
    white_label_config_fixture(account.id)
    {:ok, view, _html} = live(conn, "/app/accounts/settings")

    upload =
      file_input(view, "#white-label-form", :logo, [
        %{name: "logo.png", type: "image/png", content: "test image"}
      ])

    render_upload(upload, "logo.png")
    view |> form("#white-label-form", white_label: %{accent_color: "#123456"}) |> render_change()
    view |> element("[data-role='reset-white-label']") |> render_click()
    refute has_element?(view, "#pending-logo-preview")
    refute has_element?(view, "#branding-accent-preview")
    assert Agencies.get_white_label_config(scope, account.id) == nil
  end

  test "does not sign uploads for an unrelated user or a read-only member", %{account: account} do
    entry = %{client_name: "logo.png", client_type: "image/png", client_size: 100}
    stranger = user_fixture()

    assert {:error, :unauthorized} =
             Agencies.presign_logo_upload(Scope.for_user(stranger), account.id, entry)

    reader = user_fixture()
    reader_account = account_with_member_fixture(reader, :read_only)

    assert {:error, :unauthorized} =
             Agencies.presign_logo_upload(Scope.for_user(reader), reader_account.id, entry)
  end
end
