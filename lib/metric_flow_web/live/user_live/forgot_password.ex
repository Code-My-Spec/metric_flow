defmodule MetricFlowWeb.UserLive.ForgotPassword do
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
            <h1 class="text-2xl font-semibold text-base-content">Forgot password?</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Enter your email and we'll send a link to reset your password.
            </p>
          </div>
        </div>

        <div class="w-full rounded-box border border-neutral bg-base-200 p-5 sm:p-6">
          <.form
            for={@form}
            id="forgot-password-form"
            phx-submit="send_instructions"
            class="space-y-4"
          >
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="username"
              required
              phx-mounted={JS.focus()}
            />
            <.button
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              phx-disable-with="Sending..."
            >
              Send reset link
            </.button>
          </.form>

          <p class="mt-6 text-center text-sm text-base-content/70">
            Remembered it?
            <.link
              navigate={~p"/users/log-in"}
              id="back-to-login"
              class="font-semibold text-primary hover:underline"
            >
              Back to log in
            </.link>
          </p>
        </div>
      </div>
    </Layouts.content>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_form(%{"email" => ""}, as: "user"))}
  end

  @impl true
  def handle_event("send_instructions", %{"user" => %{"email" => email}}, socket) do
    if user = Users.get_user_by_email(email) do
      if user.confirmed_at do
        Users.deliver_password_reset_instructions(user, &url(~p"/users/reset-password/#{&1}"))
      end
    end

    {:noreply,
     socket
     |> put_flash(:info, "If that email has an account, a password reset link is on its way.")
     |> push_navigate(to: ~p"/users/log-in")}
  end
end
