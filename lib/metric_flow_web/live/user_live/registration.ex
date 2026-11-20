defmodule MetricFlowWeb.UserLive.Registration do
  use MetricFlowWeb, :live_view

  alias MetricFlow.Accounts
  alias MetricFlow.Agencies
  alias MetricFlow.Users
  alias MetricFlow.Users.{Scope, User}

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
              <%= if @registered do %>
                Registration successful
              <% else %>
                Create your account
              <% end %>
            </h1>
            <p :if={!@registered} class="mt-2 text-sm text-base-content/70">
              Track every dollar your marketing spends against the results it brings in.
            </p>
          </div>
        </div>

        <div
          :if={@registered}
          class="w-full rounded-box border border-neutral bg-base-200 p-5 text-center sm:p-6"
        >
          <p :if={@registered_account_name} class="text-base-content">
            Account "{@registered_account_name}" has been created.
          </p>
          <p class={["break-words text-base-content/80", @registered_account_name && "mt-3"]}>
            An email was sent to {@registered_email}. Please confirm your account to get started.
          </p>
        </div>

        <div
          :if={!@registered}
          class="w-full rounded-box border border-neutral bg-base-200 p-5 sm:p-6"
        >
          <div
            :if={@referral_token}
            class="mb-5 rounded-box border border-neutral bg-base-100 p-3 text-sm text-base-content/80"
            data-role="referral-notice"
          >
            You were referred by your agency. We'll link your new
            <span class="font-medium text-base-content">client</span>
            account to them so they can keep your reporting running.
          </div>

          <.link
            href={~p"/auth/google/login"}
            id="google-register"
            data-login-method="google"
            class="flex w-full items-center justify-center gap-3 rounded-box border border-neutral bg-base-100 px-4 py-2 text-sm text-base-content hover:bg-base-300"
          >
            <svg class="size-5 shrink-0" viewBox="0 0 24 24" aria-hidden="true">
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
            <span class="min-w-0 break-words">Continue with Google</span>
          </.link>

          <div class="my-6 flex items-center gap-3" aria-hidden="true">
            <span class="h-px flex-1 bg-neutral"></span>
            <span class="text-xs uppercase tracking-wider text-base-content/60">
              or sign up with your email
            </span>
            <span class="h-px flex-1 bg-neutral"></span>
          </div>

          <.form
            for={@form}
            id="registration_form"
            phx-submit="save"
            phx-change="validate"
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
              placeholder="Enter your account name, e.g. Anderson Retail Co."
            />

            <div>
              <.input
                field={@form[:account_type]}
                type="select"
                label="Account type"
                options={[
                  {"Client — my own business", "client"},
                  {"Agency — I report on others", "agency"}
                ]}
                prompt="Choose how you'll use Anderson BI"
                aria-describedby="account-type-help"
              />
              <div
                id="account-type-help"
                class="-mt-1 grid gap-2 text-sm text-base-content/80 sm:grid-cols-2"
              >
                <div class="rounded-box border border-neutral bg-base-100 p-3">
                  <p class="font-semibold text-base-content">Client</p>
                  <p class="mt-1">
                    Track marketing and business results for your own business.
                  </p>
                </div>
                <div class="rounded-box border border-neutral bg-base-100 p-3">
                  <p class="font-semibold text-base-content">Agency</p>
                  <p class="mt-1">
                    Manage reporting for multiple client businesses.
                  </p>
                </div>
              </div>
            </div>

            <.button
              phx-disable-with="Creating account..."
              class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold"
            >
              Create an account
            </.button>
          </.form>

          <p class="mt-6 text-center text-sm text-base-content/70">
            Already registered?
            <.link
              navigate={~p"/users/log-in"}
              class="font-semibold text-primary hover:underline"
            >
              Log in
            </.link>
          </p>
        </div>
      </div>
    </Layouts.content>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: MetricFlowWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(params, _session, socket) do
    changeset = Users.change_user_registration(%User{}, %{}, validate_unique: false)

    socket =
      socket
      |> assign(registered: false, registered_email: nil, registered_account_name: nil)
      |> assign(:referral_token, Map.get(params, "ref"))
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

        account = maybe_create_account(user)
        Agencies.process_new_user_auto_enrollment(user)
        maybe_associate_referring_agency(socket.assigns[:referral_token], account)

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

  defp maybe_create_account(%User{account_name: nil}), do: nil
  defp maybe_create_account(%User{account_name: ""}), do: nil

  defp maybe_create_account(%User{} = user) do
    scope = Scope.for_user(user)
    slug = user.account_name |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
    unique_slug = "#{slug}-#{:erlang.unique_integer([:positive])}"

    case Accounts.create_team_account(
           scope,
           %{name: user.account_name, slug: unique_slug},
           account_type(user.account_type)
         ) do
      {:ok, account} -> account
      {:error, _changeset} -> nil
    end
  end

  defp account_type("agency"), do: :agency
  defp account_type(_), do: :client

  defp maybe_associate_referring_agency(nil, _account), do: :ok
  defp maybe_associate_referring_agency(_token, nil), do: :ok

  defp maybe_associate_referring_agency(token, account) do
    Agencies.associate_referred_account(token, account.id)
    :ok
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
