defmodule MetricFlowWeb.Layouts do
  @moduledoc """
  Application layouts.

  - `app` — Sidebar navigation + full-viewport content area. Used by all
    authenticated `/app/*` routes including editors and dashboards.
  - `content` — Padded content area with navbar and footer. Used for public
    pages (home, login, register) and onboarding flows.

  See DESIGN.md for the Anderson BI tokens and the components these layouts
  depend on.
  """
  use MetricFlowWeb, :html

  embed_templates "layouts/*"

  @brand "Anderson BI"
  @default_logo_src "/images/anderson-bi-logo.png"

  # Blank when there's no page title (live_title's own `default` already
  # shows the brand alone) or when the page title already is the brand,
  # so the tab never reads "Anderson BI · Anderson BI".
  defp title_suffix(page_title) do
    title = page_title |> to_string() |> String.trim()

    if title == "" or title == @brand do
      ""
    else
      " · #{@brand}"
    end
  end

  defp agency_logo_url(nil), do: nil

  defp agency_logo_url(config) do
    Map.get(config, :logo_url) || Map.get(config, "logo_url")
  end

  # ---------------------------------------------------------------------------
  # App layout — sidebar + full viewport
  # ---------------------------------------------------------------------------

  @doc """
  Renders the main app layout with sidebar navigation and full-viewport content.

  All authenticated `/app/*` pages use this layout. The sidebar follows the
  Anderson BI mockup at .code_my_spec/design/anderson-bi-mockup.png.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :white_label_config, :map, default: nil
  attr :active_account_name, :string, default: nil
  attr :active_account_type, :atom, default: nil
  attr :recent_chat_sessions, :list, default: []
  slot :inner_block, required: true

  def app(assigns) do
    assigns =
      assigns
      |> assign(:agency_logo, agency_logo_url(assigns.white_label_config))
      |> assign(:default_logo_src, @default_logo_src)

    ~H"""
    <%= if @white_label_config do %>
      <style>
        :root {
          --wl-primary: <%= Map.get(@white_label_config, :primary_color) || Map.get(@white_label_config, "primary_color") %>;
          --wl-secondary: <%= Map.get(@white_label_config, :secondary_color) || Map.get(@white_label_config, "secondary_color") %>;
        }
      </style>
    <% end %>
    <div
      class="flex min-h-screen bg-base-100 text-base-content"
      data-white-label={if @white_label_config, do: "true"}
    >
      <%!-- Mobile drawer scrim --%>
      <input id="sidebar-toggle" type="checkbox" class="peer sr-only" />
      <label
        for="sidebar-toggle"
        class="fixed inset-0 z-20 hidden bg-black/60 peer-checked:block lg:peer-checked:hidden"
        aria-hidden="true"
      >
      </label>

      <%!-- Sidebar --%>
      <aside
        id="sidebar"
        aria-label="Main navigation"
        class={[
          "fixed inset-y-0 left-0 z-30 flex w-72 max-w-[85vw] flex-col",
          "border-r border-neutral bg-base-200 px-4 py-5",
          "-translate-x-full peer-checked:translate-x-0 transition-transform duration-200",
          "lg:static lg:translate-x-0 lg:max-w-none"
        ]}
      >
        <div class="mb-6 flex items-center justify-between gap-2">
          <%= if @agency_logo do %>
            <a href={~p"/app/chat"} class="flex items-center" aria-label="Home">
              <img src={@agency_logo} alt="Logo" data-role="agency-logo" class="h-9 w-auto" />
            </a>
          <% else %>
            <a
              href={~p"/app/chat"}
              class="flex items-center"
              data-role="default-logo"
              aria-label="Anderson BI home"
            >
              <img
                src={@default_logo_src}
                alt="Anderson BI"
                class="h-9 w-auto"
              />
            </a>
          <% end %>
          <label
            for="sidebar-toggle"
            class="inline-flex h-9 w-9 items-center justify-center rounded-box text-base-content lg:hidden"
            aria-label="Close navigation"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </label>
        </div>

        <a
          href={~p"/app/chat?new=1"}
          class="btn-brand-gradient flex h-12 w-full items-center justify-center gap-2 rounded-box px-4 text-sm"
          data-role="new-chat-button"
        >
          <span aria-hidden="true" class="text-xl leading-none">+</span> New Chat
        </a>

        <nav class="mt-6 flex flex-col gap-1" aria-label="Primary">
          <.sidebar_link href={~p"/app/chat"} icon="hero-chat-bubble-left-right">AI Chat</.sidebar_link>
          <.sidebar_link href={~p"/app/dashboard"} icon="hero-table-cells">All Data</.sidebar_link>
          <.sidebar_link href={~p"/app/correlations"} icon="hero-arrows-right-left">Correlations</.sidebar_link>
          <.sidebar_link href={~p"/app/integrations"} icon="hero-squares-2x2">Integrations</.sidebar_link>
          <.sidebar_link href={~p"/app/reports"} icon="hero-document-text">Reports</.sidebar_link>
        </nav>

        <div class="my-5 border-t border-neutral"></div>

        <nav class="flex flex-col gap-0.5 text-sm text-base-content/70" aria-label="Secondary">
          <.sidebar_secondary href={~p"/app/dashboards"}>Dashboards</.sidebar_secondary>
          <.sidebar_secondary href={~p"/app/insights"}>Insights</.sidebar_secondary>
          <.sidebar_secondary href={~p"/app/correlations/goals"}>Goals</.sidebar_secondary>
          <.sidebar_secondary href={~p"/app/accounts"}>Accounts</.sidebar_secondary>
          <.sidebar_secondary href={~p"/app/accounts/members"}>Members</.sidebar_secondary>
          <.sidebar_secondary href={~p"/app/accounts/settings"}>Account settings</.sidebar_secondary>
          <.sidebar_secondary href={~p"/app/accounts/invitations"}>Invitations</.sidebar_secondary>
          <%= if @active_account_type == :agency do %>
            <div class="mt-2 text-xs font-semibold uppercase tracking-wider text-base-content/50">
              Agency
            </div>
            <.sidebar_secondary href={~p"/app/agency/clients"}>Clients</.sidebar_secondary>
            <.sidebar_secondary href={~p"/app/agency/plans"}>Plans</.sidebar_secondary>
            <.sidebar_secondary href={~p"/app/agency/subscriptions"}>Subscriptions</.sidebar_secondary>
            <.sidebar_secondary href={~p"/app/agency/settings"}>Agency settings</.sidebar_secondary>
            <.sidebar_secondary href={~p"/app/agency/stripe-connect"}>Stripe Connect</.sidebar_secondary>
          <% end %>
        </nav>

        <section
          class="mt-5"
          aria-label="Recent conversations"
          data-role="recent-chat-sessions"
        >
          <h2 class="mb-2 px-2 text-xs font-semibold uppercase tracking-wider text-base-content/50">
            Recent conversations
          </h2>
          <ul class="flex flex-col gap-0.5">
            <li :for={session <- @recent_chat_sessions}>
              <.link
                navigate={~p"/app/chat/#{session.id}"}
                class="block truncate rounded-box px-3 py-1.5 text-sm text-base-content/80 hover:bg-base-300"
              >
                {session.title || "Untitled chat"}
              </.link>
            </li>
            <li :if={@recent_chat_sessions == []} class="px-3 py-1 text-xs text-base-content/50">
              No recent conversations yet.
            </li>
          </ul>
        </section>

        <div class="mt-auto pt-4">
          <a
            href={~p"/app/accounts"}
            class="flex h-12 w-full items-center gap-3 rounded-box border border-neutral bg-base-100 px-3 text-sm hover:bg-base-300"
            data-role="account-picker"
          >
            <.icon name="hero-building-office-2" class="size-4 shrink-0" />
            <span data-role="current-account-name" class="min-w-0 flex-1 truncate">
              {@active_account_name || "No account"}
            </span>
            <.icon name="hero-chevron-up-down" class="size-4 shrink-0 opacity-60" />
          </a>
        </div>
      </aside>

      <div class="flex min-w-0 flex-1 flex-col">
        <%!-- Top bar --%>
        <header class="flex h-16 items-center gap-3 border-b border-neutral bg-base-100 px-4 sm:px-6">
          <label
            for="sidebar-toggle"
            class="inline-flex h-10 w-10 items-center justify-center rounded-box text-base-content lg:hidden"
            aria-label="Open navigation"
            data-role="open-sidebar"
          >
            <.icon name="hero-bars-3" class="size-5" />
          </label>
          <div class="flex-1"></div>
          <a
            href="mailto:support@metric-flow.app"
            class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-neutral text-base-content/80 hover:text-base-content"
            aria-label="Help"
            data-role="help-link"
          >
            <.icon name="hero-question-mark-circle" class="size-5" />
          </a>
          <%= if @current_scope do %>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                class="avatar placeholder cursor-pointer"
                aria-label="Account menu"
                data-role="avatar-menu"
              >
                <div class="w-9 rounded-full bg-primary text-primary-content">
                  <span class="text-sm">
                    {String.first(@current_scope.user.email) |> String.upcase()}
                  </span>
                </div>
              </div>
              <ul
                tabindex="-1"
                class="menu dropdown-content z-10 mt-3 w-56 rounded-box border border-neutral bg-base-200 p-2 shadow"
              >
                <li class="menu-title text-xs">{@current_scope.user.email}</li>
                <li><a href={~p"/app/users/settings"}>User settings</a></li>
                <li>
                  <.link href={~p"/users/log-out"} method="delete">Log out</.link>
                </li>
              </ul>
            </div>
          <% end %>
        </header>

        <main class="flex-1 overflow-x-hidden px-4 py-6 sm:px-6 lg:px-8">
          {render_slot(@inner_block)}
        </main>
      </div>

      <.flash_group flash={@flash} />

      <.live_component
        module={MetricFlowWeb.FeedbackWidget}
        id="codemyspec-feedback"
        current_scope={@current_scope}
      />
    </div>
    """
  end

  attr :href, :string, required: true
  attr :icon, :string, required: true
  slot :inner_block, required: true

  defp sidebar_link(assigns) do
    ~H"""
    <.link
      href={@href}
      class="flex items-center gap-3 rounded-box border border-transparent px-3 py-2 text-sm text-base-content hover:border-neutral hover:bg-base-300"
    >
      <.icon name={@icon} class="size-5 shrink-0 opacity-80" /> {render_slot(@inner_block)}
    </.link>
    """
  end

  attr :href, :string, required: true
  slot :inner_block, required: true

  defp sidebar_secondary(assigns) do
    ~H"""
    <.link
      href={@href}
      class="rounded-box px-3 py-1.5 text-sm text-base-content/70 hover:bg-base-300 hover:text-base-content"
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  # ---------------------------------------------------------------------------
  # Content layout — padded content with navbar and footer
  # ---------------------------------------------------------------------------

  @doc """
  Renders the content layout with top navbar, padded content area, and footer.

  Used for public pages (home, login, register) and onboarding flows that
  don't need the sidebar navigation.
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :white_label_config, :map, default: nil
  attr :active_account_name, :string, default: nil
  slot :inner_block, required: true

  def content(assigns) do
    assigns =
      assigns
      |> assign(:agency_logo, agency_logo_url(assigns.white_label_config))
      |> assign(:default_logo_src, @default_logo_src)

    ~H"""
    <%= if @white_label_config do %>
      <style>
        :root {
          --wl-primary: <%= Map.get(@white_label_config, :primary_color) || Map.get(@white_label_config, "primary_color") %>;
          --wl-secondary: <%= Map.get(@white_label_config, :secondary_color) || Map.get(@white_label_config, "secondary_color") %>;
        }
      </style>
    <% end %>
    <div
      class="flex min-h-screen flex-col bg-base-100 text-base-content"
      data-white-label={if @white_label_config, do: "true"}
    >
      <header class="flex items-center justify-between gap-3 border-b border-neutral px-4 py-3 sm:px-6 lg:px-8">
        <%= if @agency_logo do %>
          <a href="/" class="flex items-center">
            <img
              src={@agency_logo}
              alt="Agency logo"
              data-role="agency-logo"
              class="h-9 w-auto"
            />
          </a>
        <% else %>
          <a href="/" class="flex items-center" data-role="default-logo">
            <img
              src={@default_logo_src}
              alt="Anderson BI"
              class="h-9 w-auto"
            />
          </a>
        <% end %>
        <div class="flex items-center gap-2">
          <%= if @current_scope do %>
            <a href={~p"/app/chat"} class="btn-brand-gradient rounded-box px-4 py-2 text-sm">
              Open App
            </a>
            <div class="dropdown dropdown-end">
              <div
                tabindex="0"
                role="button"
                class="avatar placeholder cursor-pointer"
                aria-label="Account menu"
              >
                <div class="w-9 rounded-full bg-primary text-primary-content">
                  <span class="text-sm">
                    {String.first(@current_scope.user.email) |> String.upcase()}
                  </span>
                </div>
              </div>
              <ul
                tabindex="-1"
                class="menu dropdown-content z-10 mt-3 w-56 rounded-box border border-neutral bg-base-200 p-2 shadow"
              >
                <li class="menu-title text-xs">{@current_scope.user.email}</li>
                <li><a href={~p"/app/users/settings"}>Settings</a></li>
                <li>
                  <.link href={~p"/users/log-out"} method="delete">Log out</.link>
                </li>
              </ul>
            </div>
          <% else %>
            <a
              href={~p"/users/log-in"}
              class="rounded-box px-4 py-2 text-sm text-base-content/80 hover:text-base-content"
            >
              Log in
            </a>
            <a href={~p"/users/register"} class="btn-brand-gradient rounded-box px-4 py-2 text-sm">
              Register
            </a>
          <% end %>
        </div>
      </header>

      <main class="mf-content flex-1 overflow-x-hidden px-4 py-10 sm:px-6 lg:px-8">
        <div class="mx-auto max-w-[1400px] space-y-4">
          {render_slot(@inner_block)}
        </div>
      </main>

      <footer class="border-t border-neutral px-4 py-6 text-center text-sm text-base-content/60 sm:px-6 lg:px-8">
        <div class="flex flex-wrap justify-center gap-4">
          <a href="/privacy" class="hover:text-base-content">Privacy Policy</a>
          <a href="/terms" class="hover:text-base-content">Terms of Service</a>
          <a href="mailto:support@metric-flow.app" class="hover:text-base-content">Contact</a>
        </div>
        <p class="mt-2">&copy; {Date.utc_today().year} Anderson BI. All rights reserved.</p>
      </footer>
    </div>

    <.flash_group flash={@flash} />

    <.live_component
      module={MetricFlowWeb.FeedbackWidget}
      id="codemyspec-feedback"
      current_scope={@current_scope}
    />
    """
  end

  # ---------------------------------------------------------------------------
  # Shared components
  # ---------------------------------------------------------------------------

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
