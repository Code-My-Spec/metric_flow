defmodule MetricFlowWeb.UserLive.Login do
  use MetricFlowWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto flex min-h-[70vh] max-w-md items-center px-4 py-10">
        <div class="w-full rounded-2xl border border-base-300 bg-base-100 p-6 shadow-xl sm:p-9">
          <div class="mb-8 text-center">
            <h1 class="text-3xl font-semibold tracking-tight">Log in</h1>
            <p class="mt-2 text-sm text-base-content/65">
              <%= if @current_scope do %>
                You need to reauthenticate to perform sensitive actions on your account.
              <% else %>
                Welcome back to MetricFlow.
              <% end %>
            </p>
          </div>
          <div
            :if={local_mail_adapter?()}
            class="mb-6 rounded-lg border border-info/30 bg-info/10 p-3 text-sm"
          >
            You are running the local mail adapter. <.link
              href="/dev/mailbox"
              class="font-medium underline"
            >View sent emails</.link>.
          </div>
          <.form
            for={@form}
            id="login_form_password"
            action={~p"/users/log-in"}
            phx-submit="submit_password"
            phx-trigger-action={@trigger_submit}
            class="space-y-5"
          >
            <input :if={!@current_scope} type="hidden" name={@form[:remember_me].name} value="true" />
            <.input
              id="password_email"
              readonly={!!@current_scope}
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
              autocomplete="current-password"
              required
            />
            <div class="text-right">
              <.link
                navigate={~p"/users/forgot-password"}
                id="forgot-password-link"
                class="text-sm font-medium text-primary transition hover:underline"
              >
                Forgot password?
              </.link>
            </div>
            <.button
              class="btn btn-primary w-full transition hover:-translate-y-0.5"
              phx-disable-with="Logging in..."
            >
              Log in
            </.button>
          </.form>
          <p :if={!@current_scope} class="mt-8 text-center text-sm text-base-content/70">
            New to MetricFlow?
            <.link
              navigate={~p"/users/register"}
              id="register-link"
              class="font-semibold text-primary hover:underline"
            >
              Sign up
            </.link>
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    {:ok, assign(socket, form: to_form(%{"email" => email}, as: "user"), trigger_submit: false)}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  defp local_mail_adapter? do
    Application.get_env(:metric_flow, MetricFlow.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
