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
      <div class="mx-auto max-w-2xl space-y-6 overflow-x-hidden">
        <header class="space-y-1">
          <h1 class="text-2xl font-semibold text-base-content break-words">Account Settings</h1>
          <p class="text-sm text-base-content/70">
            Manage your sign-in details and connected services for Anderson BI.
          </p>
        </header>

        <section
          data-role="settings-section"
          aria-labelledby="settings-email-heading"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <h2 id="settings-email-heading" class="text-lg font-semibold text-base-content">
            Email address
          </h2>
          <p class="mt-1 text-sm text-base-content/70 break-words">
            A confirmation link goes to the new address before the change takes effect.
          </p>
          <.form
            for={@email_form}
            id="email_form"
            phx-submit="update_email"
            phx-change="validate_email"
            class="mt-4 space-y-4"
          >
            <.input
              field={@email_form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
            />
            <.button
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
              phx-disable-with="Changing..."
            >
              Change Email
            </.button>
          </.form>
        </section>

        <section
          data-role="settings-section"
          aria-labelledby="settings-password-heading"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <h2 id="settings-password-heading" class="text-lg font-semibold text-base-content">
            Password
          </h2>
          <p class="mt-1 text-sm text-base-content/70">
            Pick a new password. The next sign-in uses this one.
          </p>
          <.form
            for={@password_form}
            id="password_form"
            action={~p"/app/users/update-password"}
            method="post"
            phx-change="validate_password"
            phx-submit="update_password"
            phx-trigger-action={@trigger_submit}
            class="mt-4 space-y-4"
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
            <.button
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
              phx-disable-with="Saving..."
            >
              Save Password
            </.button>
          </.form>
        </section>

        <section
          data-role="settings-section"
          aria-labelledby="settings-services-heading"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
        >
          <h2 id="settings-services-heading" class="text-lg font-semibold text-base-content">
            Connected services
          </h2>
          <p class="mt-1 text-sm text-base-content/70">
            Let outside tools reach your Anderson BI account on your behalf.
          </p>

          <div class="mt-4 flex flex-wrap items-center gap-3 rounded-box border border-neutral bg-base-100 p-4">
            <div class="flex min-w-0 flex-1 items-center gap-3">
              <svg
                class="h-8 w-8 shrink-0 text-base-content"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <path
                  d="M12 2L2 7l10 5 10-5-10-5zM2 17l10 5 10-5M2 12l10 5 10-5"
                  stroke="currentColor"
                  stroke-width="2"
                  fill="none"
                  stroke-linecap="round"
                  stroke-linejoin="round"
                />
              </svg>
              <div class="min-w-0">
                <div class="break-words font-medium text-base-content">CodeMySpec</div>
                <%= if @codemyspec_connected do %>
                  <div class="text-sm text-success">Connected</div>
                <% else %>
                  <div class="text-sm text-base-content/60">Not connected</div>
                <% end %>
              </div>
            </div>
            <%= if not @codemyspec_connected do %>
              <.link
                href={~p"/app/integrations/oauth/codemyspec"}
                class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
              >
                Connect
              </.link>
            <% end %>
          </div>

          <div
            id="agent-access"
            class="mt-4 rounded-box border border-neutral bg-base-100 p-4 text-sm text-base-content/70"
          >
            <span class="font-medium text-base-content">Connect an AI agent:</span>
            add
            <code class="break-all rounded-box bg-base-200 px-1.5 py-0.5 text-xs text-base-content select-all">
              {url(~p"/mcp")}
            </code>
            as an MCP server in Claude, ChatGPT or another client, then sign in when asked.
          </div>
        </section>

        <div :if={@codemyspec_connected} data-role="danger-zone-separator" class="pt-2">
          <div class="h-px bg-neutral" aria-hidden="true"></div>
          <h2 class="mt-6 text-xs font-semibold uppercase tracking-wider text-error">
            Danger zone
          </h2>
        </div>

        <section
          :if={@codemyspec_connected}
          data-role="danger-zone"
          aria-labelledby="settings-disconnect-heading"
          class="rounded-box border border-error bg-base-200 p-4 sm:p-6"
        >
          <h3
            id="settings-disconnect-heading"
            class="text-lg font-semibold text-base-content"
          >
            Disconnect CodeMySpec
          </h3>
          <p class="mt-1 text-sm text-base-content/70">
            Agents signed in through this connection lose access immediately. You can reconnect later.
          </p>
          <button
            phx-click="disconnect_codemyspec"
            data-confirm="Are you sure you want to disconnect CodeMySpec?"
            class="mt-4 w-full rounded-box border border-error bg-base-100 px-4 py-2 text-sm font-semibold text-error hover:bg-base-300 sm:w-auto"
          >
            Disconnect
          </button>
        </section>
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
