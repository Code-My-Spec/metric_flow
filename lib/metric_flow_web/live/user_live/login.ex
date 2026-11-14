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
          <.link
            href={~p"/auth/google/login"}
            id="google-login"
            data-login-method="google"
            class="btn btn-outline w-full gap-3 mb-5"
          >
            <svg class="size-5" viewBox="0 0 24 24" aria-hidden="true">
              <path
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92a5.06 5.06 0 0 1-2.2 3.32v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.1z"
                fill="#4285F4"
              />
              <path
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
                fill="#34A853"
              />
              <path
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18A10.96 10.96 0 0 0 1 12c0 1.77.42 3.45 1.18 4.93l2.85-2.22.81-.62z"
                fill="#FBBC05"
              />
              <path
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"
                fill="#EA4335"
              />
            </svg>
            <span>Continue with Google</span>
          </.link>
          <div class="divider text-xs text-base-content/50">or</div>
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
