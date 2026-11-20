defmodule MetricFlowWeb.UserLive.Confirmation do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Users

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.content
      flash={@flash}
      current_scope={@current_scope}
      active_account_name={assigns[:active_account_name]}
    >
      <div class="mx-auto flex w-full max-w-md flex-col items-center gap-6 px-1 py-4 sm:py-8">
        <div class="flex flex-col items-center gap-3">
          <img
            src="/images/anderson-bi-logo.png"
            alt="Anderson BI"
            data-role="default-logo"
            class="h-10 w-auto"
          />
          <div class="text-center">
            <h1 class="text-2xl font-semibold text-base-content">
              <%= if @user.confirmed_at do %>
                Welcome back
              <% else %>
                Confirm your account
              <% end %>
            </h1>
            <p class="mt-2 break-words text-sm text-base-content/70">{@user.email}</p>
          </div>
        </div>

        <div class="w-full rounded-box border border-neutral bg-base-200 p-5 sm:p-6">
          <.form
            :if={!@user.confirmed_at}
            for={@form}
            id="confirmation_form"
            phx-mounted={JS.focus_first()}
            phx-submit="submit"
            action={~p"/users/log-in?_action=confirmed"}
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <.button
              name={@form[:remember_me].name}
              value="true"
              phx-disable-with="Confirming..."
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
            >
              Confirm and stay logged in
            </.button>
            <.button
              phx-disable-with="Confirming..."
              class="w-full rounded-box border border-neutral bg-base-100 px-4 py-2 text-sm font-semibold text-base-content hover:bg-base-300"
            >
              Confirm and log in only this time
            </.button>
          </.form>

          <.form
            :if={@user.confirmed_at}
            for={@form}
            id="login_form"
            phx-submit="submit"
            phx-mounted={JS.focus_first()}
            action={~p"/users/log-in"}
            phx-trigger-action={@trigger_submit}
            class="space-y-3"
          >
            <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
            <%= if @current_scope do %>
              <.button
                phx-disable-with="Logging in..."
                class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              >
                Log in
              </.button>
            <% else %>
              <.button
                name={@form[:remember_me].name}
                value="true"
                phx-disable-with="Logging in..."
                class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              >
                Keep me logged in on this device
              </.button>
              <.button
                phx-disable-with="Logging in..."
                class="w-full rounded-box border border-neutral bg-base-100 px-4 py-2 text-sm font-semibold text-base-content hover:bg-base-300"
              >
                Log me in only this time
              </.button>
            <% end %>
          </.form>

          <p
            :if={!@user.confirmed_at}
            class="mt-6 rounded-box border border-neutral bg-base-100 p-3 text-sm text-base-content/80"
          >
            Tip: If you prefer passwords, you can enable them in the user settings.
          </p>
        </div>
      </div>
    </Layouts.content>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Users.get_user_by_magic_link_token(token) do
      %{confirmed_at: nil} = user ->
        # A LiveView mount can't set an HTTP session cookie itself, so the
        # unconfirmed-user confirm form (below) must actually submit through
        # the controller for login to take effect. Arming trigger_submit as
        # soon as the socket connects makes it submit automatically instead
        # of waiting for a click, via the same phx-trigger-action mechanism
        # already used for the confirmed-user form.
        form = to_form(%{"token" => token}, as: "user")

        {:ok, assign(socket, user: user, form: form, trigger_submit: connected?(socket)),
         temporary_assigns: [form: nil]}

      %{} = user ->
        form = to_form(%{"token" => token}, as: "user")

        {:ok, assign(socket, user: user, form: form, trigger_submit: false),
         temporary_assigns: [form: nil]}

      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Magic link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/log-in")}
    end
  end

  @impl true
  def handle_event("submit", %{"user" => params}, socket) do
    {:noreply, assign(socket, form: to_form(params, as: "user"), trigger_submit: true)}
  end
end
