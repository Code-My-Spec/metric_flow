defmodule MetricFlowSpex.UserPromptedForAccountNameSpex do
  use MetricFlowSpex.Case
  import Phoenix.LiveViewTest

  spex "User is prompted for an account name during registration", criterion: 516 do
    scenario "the registration form prompts for an account name before completion" do
      given_ "Dana is registering a new account", context do
        {:ok, context}
      end

      when_ "she reaches the registration form", context do
        {:ok, view, _html} = live(context.conn, "/users/register")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "she is prompted to enter an account name before completing registration", context do
        assert has_element?(context.view, "input[name='user[account_name]']")
        assert render(context.view) =~ "account name"
        {:ok, context}
      end
    end
  end
end
