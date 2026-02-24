defmodule MetricFlowWeb.UserLive.Registration do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Users
  alias MetricFlow.Users.{Scope, User}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm">
        <div :if={@registered} class="text-center">
          <.header>
            Registration successful
          </.header>

          <p :if={@registered_account_name} class="mt-4">
            Account "{@registered_account_name}" has been created.
          </p>

          <p class="mt-4">
            An email was sent to {@registered_email}.
            Please confirm your account to get started.
          </p>
        </div>

        <div :if={!@registered}>
          <div class="text-center">
            <.header>
              Register for an account
              <:subtitle>
                Already registered?
                <.link navigate={~p"/users/log-in"} class="font-semibold text-brand hover:underline">
                  Log in
                </.link>
                to your account now.
              </:subtitle>
            </.header>
          </div>

          <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />

            <.input
              field={@form[:password]}
              type="password"
              label="Password"
              required
            />

            <.input
              field={@form[:account_name]}
              type="text"
              label="Account name"
              placeholder="Enter your account name"
            />

            <.input
              field={@form[:account_type]}
              type="select"
              label="Account type"
              options={[{"Client", "client"}, {"Agency", "agency"}]}
              prompt="Select account type"
            />

            <.button phx-disable-with="Creating account..." class="btn btn-primary w-full">
              Create an account
            </.button>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: MetricFlowWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, _session, socket) do
    changeset = Users.change_user_registration(%User{}, %{}, validate_unique: false)

    socket =
      socket
      |> assign(registered: false, registered_email: nil, registered_account_name: nil)
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("save", %{"user" => user_params}, socket) do
    case Users.register_user(user_params) do
      {:ok, user} ->
        {:ok, _} =
          Users.deliver_login_instructions(
            user,
            &url(~p"/users/log-in/#{&1}")
          )

        maybe_create_account(user)

        {:noreply,
         assign(socket,
           registered: true,
           registered_email: user.email,
           registered_account_name: user.account_name
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset = Users.change_user_registration(%User{}, user_params, validate_unique: false)
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp maybe_create_account(%User{account_name: nil}), do: :ok
  defp maybe_create_account(%User{account_name: ""}), do: :ok

  defp maybe_create_account(%User{} = user) do
    scope = Scope.for_user(user)
    slug = user.account_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    unique_slug = "#{slug}-#{:erlang.unique_integer([:positive])}"

    Accounts.create_team_account(scope, %{
      name: user.account_name,
      slug: unique_slug
    })
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
