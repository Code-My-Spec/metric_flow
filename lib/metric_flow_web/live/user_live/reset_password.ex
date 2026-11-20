defmodule MetricFlowWeb.UserLive.ResetPassword do
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
            <h1 class="text-2xl font-semibold text-base-content">Reset password</h1>
            <p class="mt-2 text-sm text-base-content/70">
              Choose a new password for your account.
            </p>
          </div>
        </div>

        <div class="w-full rounded-box border border-neutral bg-base-200 p-5 sm:p-6">
          <.form
            for={@form}
            id="reset-password-form"
            phx-submit="reset_password"
            class="space-y-4"
          >
            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              required
              phx-mounted={JS.focus()}
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              required
            />
            <.button
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
              phx-disable-with="Saving..."
            >
              Reset password
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
  def mount(%{"token" => token}, _session, socket) do
    case Users.get_user_by_password_reset_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "The reset link is invalid or has expired.")
         |> push_navigate(to: ~p"/users/forgot-password")}

      user ->
        form = user |> Users.change_user_password(%{}, hash_password: false) |> to_form()
        {:ok, assign(socket, form: form, token: token)}
    end
  end

  @impl true
  def handle_event("reset_password", %{"user" => params}, socket) do
    case Users.reset_user_password(socket.assigns.token, params) do
      {:ok, {_user, _expired_tokens}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password updated. Log in with your new password.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}

      {:error, :invalid_token} ->
        {:noreply,
         socket
         |> put_flash(:error, "The reset link is invalid or has expired.")
         |> push_navigate(to: ~p"/users/forgot-password")}
    end
  end
end
