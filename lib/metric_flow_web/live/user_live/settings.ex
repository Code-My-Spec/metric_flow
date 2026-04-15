defmodule MetricFlowWeb.UserLive.Settings do
  use MetricFlowWeb, :live_view

  on_mount {MetricFlowWeb.UserAuth, :require_sudo_mode}

  alias MetricFlow.Integrations
  alias MetricFlow.Users

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
    >
    <div class="mx-auto">
      <.header>
        Account Settings
        <:subtitle>Manage your account email address and password settings</:subtitle>
      </.header>
    </div>

    <.form for={@email_form} id="email_form" phx-submit="update_email" phx-change="validate_email">
      <.input
        field={@email_form[:email]}
        type="email"
        label="Email"
        autocomplete="username"
        required
      />
      <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
    </.form>

    <div class="divider" />

    <.form
      for={@password_form}
      id="password_form"
      action={~p"/app/users/update-password"}
      method="post"
      phx-change="validate_password"
      phx-submit="update_password"
      phx-trigger-action={@trigger_submit}
    >
      <input
        name={@password_form[:email].name}
        type="hidden"
        id="hidden_user_email"
        autocomplete="username"
        value={@current_email}
      />
      <.input
        field={@password_form[:password]}
        type="password"
        label="New password"
        autocomplete="new-password"
        required
      />
      <.input
        field={@password_form[:password_confirmation]}
        type="password"
        label="Confirm new password"
        autocomplete="new-password"
      />
      <.button variant="primary" phx-disable-with="Saving...">
        Save Password
      </.button>
    </.form>
    <div class="divider" />

    <div class="space-y-4">
      <h3 class="text-lg font-semibold">Connected Services</h3>

      <div class="border rounded-lg p-4 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <svg class="w-8 h-8" viewBox="0 0 24 24" fill="currentColor">
            <path d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
          <div>
            <div class="font-medium">CodeMySpec</div>
            <%= if @codemyspec_connected do %>
              <div class="text-sm text-success">Connected</div>
            <% else %>
              <div class="text-sm text-base-content/50">Not connected</div>
            <% end %>
          </div>
        </div>

        <%= if @codemyspec_connected do %>
          <button
            phx-click="disconnect_codemyspec"
            data-confirm="Are you sure you want to disconnect CodeMySpec?"
            class="btn btn-sm btn-outline btn-error"
          >
            Disconnect
          </button>
        <% else %>
          <.link href={~p"/app/integrations/oauth/codemyspec"} class="btn btn-sm btn-primary">
            Connect
          </.link>
        <% end %>
      </div>
    </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Users.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/app/users/settings")}
  end

  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    scope = socket.assigns.current_scope
    email_changeset = Users.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Users.change_user_password(user, %{}, hash_password: false)

    socket =
      socket
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)
      |> assign(:codemyspec_connected, Integrations.connected?(scope, :codemyspec))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Users.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Users.sudo_mode?(user)

    case Users.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Users.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/app/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Users.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("disconnect_codemyspec", _params, socket) do
    scope = socket.assigns.current_scope

    case Integrations.disconnect(scope, :codemyspec) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign(:codemyspec_connected, false)
         |> put_flash(:info, "Disconnected from CodeMySpec.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to disconnect.")}
    end
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Users.sudo_mode?(user)

    case Users.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end
end
