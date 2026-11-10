defmodule MetricFlowWeb.UserLive.ResetPassword do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Users

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto flex min-h-[70vh] max-w-md items-center px-4 py-10">
        <div class="w-full rounded-2xl border border-base-300 bg-base-100 p-6 shadow-xl sm:p-9">
          <h1 class="text-3xl font-semibold tracking-tight">Reset password</h1>
          <p class="mt-3 text-sm text-base-content/70">Choose a new password for your account.</p>
          <.form
            for={@form}
            id="reset-password-form"
            phx-submit="reset_password"
            class="mt-7 space-y-5"
          >
            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              required
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              required
            />
            <.button class="btn btn-primary w-full" phx-disable-with="Saving...">
              Reset password
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
