defmodule MetricFlowSpex.InvalidEmailOrWeakPasswordBlocksRegistrationSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "Invalid email format or weak password blocks registration", criterion: 521 do
    scenario "a malformed email shows a validation error and creates no account" do
      given_ "Dana is on the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she enters a malformed email and submits the registration form", context do
        context.view
        |> form("#registration_form", user: %{
          email: "not-an-email",
          password: "SecurePassword123!",
          account_name: "Dana Retry Co"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the form shows a validation error and no account is created", context do
        assert render(context.view) =~ "must have the @ sign and no spaces"

        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "not-an-email",
          password: "AnotherSecurePass456!",
          account_name: "Dana Retry Co Two"
        })
        |> render_submit()

        refute render(view) =~ "has already been taken"

        {:ok, context}
      end
    end

    scenario "a password that does not meet the strength requirement blocks registration" do
      given_ "Dana is on the registration page", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "she enters a weak password and submits the registration form", context do
        context.view
        |> form("#registration_form", user: %{
          email: "weakpass_dana@example.com",
          password: "short",
          account_name: "Dana Weak Co"
        })
        |> render_submit()

        {:ok, context}
      end

      then_ "the form shows a password strength error and no account is created", context do
        assert render(context.view) =~ "should be at least 12 character"

        {:ok, view, _html} = live(context.conn, "/users/register")

        view
        |> form("#registration_form", user: %{
          email: "weakpass_dana@example.com",
          password: "AnotherSecurePass456!",
          account_name: "Dana Weak Co Two"
        })
        |> render_submit()

        refute render(view) =~ "has already been taken"

        {:ok, context}
      end
    end
  end
end
