defmodule MetricFlowWeb.UserLive.ForgotPassword do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Users

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto flex min-h-[70vh] max-w-md items-center px-4 py-10">
        <div class="w-full rounded-2xl border border-base-300 bg-base-100 p-6 shadow-xl sm:p-9">
          <h1 class="text-3xl font-semibold tracking-tight">Forgot password?</h1>
          <p class="mt-3 text-sm text-base-content/70">
            Enter your email address and we'll send a link to reset your password.
          </p>
          <.form
            for={@form}
            id="forgot-password-form"
            phx-submit="send_instructions"
            class="mt-7 space-y-5"
          >
            <.input field={@form[:email]} type="email" label="Email" autocomplete="username" required />
            <.button class="btn btn-primary w-full" phx-disable-with="Sending...">
              Send reset link
            </.button>
          </.form>
          <.link
            navigate={~p"/users/log-in"}
            id="back-to-login"
            class="mt-6 inline-block text-sm font-medium text-primary hover:underline"
          >
            Back to log in
          </.link>
        </div>
      </div>
    </Layouts.app>
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
