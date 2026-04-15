defmodule MetricFlowWeb.Layouts do
  @moduledoc """
  Application layouts.

  - `app` — Sidebar navigation + full-viewport content area. Used by all
    authenticated `/app/*` routes including editors and dashboards.
  - `content` — Padded content area with navbar and footer. Used for public
    pages (home, login, register) and onboarding flows.
  """
  use MetricFlowWeb, :html

  embed_templates "layouts/*"

  # ---------------------------------------------------------------------------
  # App layout — sidebar + full viewport
  # ---------------------------------------------------------------------------

  @doc """
  Renders the main app layout with sidebar navigation and full-viewport content.

  All authenticated `/app/*` pages use this layout. The sidebar provides
  navigation to every section. Content fills the remaining viewport.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <div>Full-height content</div>
      </Layouts.app>
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :white_label_config, :map, default: nil
  attr :active_account_name, :string, default: nil
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @white_label_config do %>
      <style>
        :root {
          --wl-primary: <%= Map.get(@white_label_config, :primary_color) || Map.get(@white_label_config, "primary_color") %>;
          --wl-secondary: <%= Map.get(@white_label_config, :secondary_color) || Map.get(@white_label_config, "secondary_color") %>;
        }
      </style>
    <% end %>
    <div class="drawer lg:drawer-open min-h-screen" data-white-label={if @white_label_config, do: "true"}>
      <input id="drawer-toggle" type="checkbox" class="drawer-toggle" />

      <div class="drawer-content flex flex-col bg-base-100">
        <%!-- Top bar — mobile hamburger + account info --%>
        <div class="navbar bg-base-200 border-b border-base-300 lg:hidden">
          <div class="flex-none">
            <label for="drawer-toggle" class="btn btn-square btn-ghost">
              <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="inline-block w-5 h-5 stroke-current">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </label>
          </div>
          <div class="flex-1">
            <%= if @white_label_config && (Map.get(@white_label_config, :logo_url) || Map.get(@white_label_config, "logo_url")) do %>
              <a href="/app/dashboard" class="btn btn-ghost">
                <img
                  src={Map.get(@white_label_config, :logo_url) || Map.get(@white_label_config, "logo_url")}
                  alt="Logo"
                  data-role="agency-logo"
                  class="h-6 w-auto"
                />
              </a>
            <% else %>
              <a href="/app/dashboard" class="btn btn-ghost text-lg font-bold tracking-tight" data-role="default-logo">
                <span class="text-primary">Metric</span><span class="text-accent">Flow</span>
              </a>
            <% end %>
          </div>
          <div class="flex-none">
            <%= if @active_account_name do %>
              <span class="text-sm text-base-content/70 mr-2">{@active_account_name}</span>
            <% end %>
          </div>
        </div>

        <%!-- Main content — full viewport --%>
        <main class="flex-1 overflow-auto">
          {render_slot(@inner_block)}
        </main>
      </div>

      <%!-- Sidebar --%>
      <div class="drawer-side z-20">
        <label for="drawer-toggle" class="drawer-overlay"></label>
        <aside class="w-64 min-h-full bg-base-200 flex flex-col">
          <%!-- Logo --%>
          <div class="p-4 border-b border-base-300">
            <%= if @white_label_config && (Map.get(@white_label_config, :logo_url) || Map.get(@white_label_config, "logo_url")) do %>
              <a href="/app/dashboard" class="flex items-center gap-2">
                <img
                  src={Map.get(@white_label_config, :logo_url) || Map.get(@white_label_config, "logo_url")}
                  alt="Logo"
                  data-role="agency-logo"
                  class="h-7 w-auto"
                />
              </a>
            <% else %>
              <a href="/app/dashboard" class="flex items-center gap-2 text-lg font-bold tracking-tight">
                <span class="text-primary">Metric</span><span class="text-accent">Flow</span>
              </a>
            <% end %>
            <%= if @active_account_name do %>
              <p data-role="current-account-name" class="text-xs text-base-content/50 mt-1 truncate">{@active_account_name}</p>
            <% end %>
          </div>

          <%!-- Navigation --%>
          <ul class="menu p-3 w-full flex-1 text-sm">
            <li><a href={~p"/app/dashboard"}>Dashboard</a></li>

            <li>
              <details>
                <summary>Integrations</summary>
                <ul>
                  <li><a href={~p"/app/integrations"}>All Integrations</a></li>
                  <li><a href={~p"/app/integrations/connect"}>Connect New</a></li>
                  <li><a href={~p"/app/integrations/sync-history"}>Sync History</a></li>
                </ul>
              </details>
            </li>

            <li>
              <details>
                <summary>Visualizations</summary>
                <ul>
                  <li><a href={~p"/app/visualizations"}>Library</a></li>
                  <li><a href={~p"/app/visualizations/new"}>New Visualization</a></li>
                </ul>
              </details>
            </li>

            <li>
              <details>
                <summary>Reports</summary>
                <ul>
                  <li><a href={~p"/app/reports"}>All Reports</a></li>
                  <li><a href={~p"/app/reports/generate"}>Generate Report</a></li>
                </ul>
              </details>
            </li>

            <li>
              <details>
                <summary>Dashboards</summary>
                <ul>
                  <li><a href={~p"/app/dashboards"}>All Dashboards</a></li>
                  <li><a href={~p"/app/dashboards/new"}>New Dashboard</a></li>
                </ul>
              </details>
            </li>

            <li>
              <details>
                <summary>Intelligence</summary>
                <ul>
                  <li><a href={~p"/app/insights"}>Insights</a></li>
                  <li><a href={~p"/app/chat"}>Chat</a></li>
                  <li><a href={~p"/app/correlations"}>Correlations</a></li>
                  <li><a href={~p"/app/correlations/goals"}>Goals</a></li>
                </ul>
              </details>
            </li>

            <li>
              <details>
                <summary>Account</summary>
                <ul>
                  <li><a href={~p"/app/accounts"}>Accounts</a></li>
                  <li><a href={~p"/app/accounts/members"}>Members</a></li>
                  <li><a href={~p"/app/accounts/settings"}>Settings</a></li>
                  <li><a href={~p"/app/accounts/invitations"}>Invitations</a></li>
                </ul>
              </details>
            </li>
          </ul>

          <%!-- Bottom: user + settings --%>
          <div class="border-t border-base-300 p-3">
            <%= if @current_scope do %>
              <div class="flex items-center gap-2 px-2 py-1">
                <div class="avatar placeholder">
                  <div class="bg-primary text-primary-content w-7 rounded-full">
                    <span class="text-xs">{String.first(@current_scope.user.email) |> String.upcase()}</span>
                  </div>
                </div>
                <div class="flex-1 min-w-0">
                  <p class="text-xs truncate">{@current_scope.user.email}</p>
                </div>
              </div>
              <ul class="menu menu-sm p-0 mt-1">
                <li><a href={~p"/app/users/settings"}>User Settings</a></li>
                <li>
                  <.link href={~p"/users/log-out"} method="delete">Log out</.link>
                </li>
              </ul>
            <% end %>
          </div>
        </aside>
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

  # ---------------------------------------------------------------------------
  # Content layout — padded content with navbar and footer
  # ---------------------------------------------------------------------------

  @doc """
  Renders the content layout with top navbar, padded content area, and footer.

  Used for public pages (home, login, register) and onboarding flows that
  don't need the sidebar navigation.

  ## Examples

      <Layouts.content flash={@flash}>
        <h1>Welcome</h1>
      </Layouts.content>
  """
  attr :flash, :map, required: true
  attr :current_scope, :map, default: nil
  attr :white_label_config, :map, default: nil
  attr :active_account_name, :string, default: nil
  slot :inner_block, required: true

  def content(assigns) do
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
      class="navbar mf-topnav px-4 sm:px-6 lg:px-8"
      data-white-label={if @white_label_config, do: "true"}
    >
      <div class="navbar-start">
        <%= if @white_label_config && (Map.get(@white_label_config, :logo_url) || Map.get(@white_label_config, "logo_url")) do %>
          <a href="/" class="btn btn-ghost">
            <img
              src={Map.get(@white_label_config, :logo_url) || Map.get(@white_label_config, "logo_url")}
              alt="Agency Logo"
              data-role="agency-logo"
              class="h-8 w-auto"
            />
          </a>
        <% else %>
          <a href="/" class="btn btn-ghost text-lg font-bold tracking-tight" data-role="default-logo">
            <span class="text-primary">Metric</span><span class="text-accent">Flow</span>
          </a>
        <% end %>
      </div>
      <div class="navbar-end gap-2">
        <%= if @current_scope do %>
          <a href={~p"/app/dashboard"} class="btn btn-primary btn-sm">Open App</a>
          <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-circle avatar placeholder">
              <div class="bg-primary text-primary-content w-8 rounded-full">
                <span class="text-xs">
                  {String.first(@current_scope.user.email) |> String.upcase()}
                </span>
              </div>
            </div>
            <ul tabindex="-1" class="menu menu-sm dropdown-content bg-base-200 rounded-box z-10 mt-3 w-52 p-2 shadow">
              <li class="menu-title text-xs">{@current_scope.user.email}</li>
              <li><a href={~p"/app/users/settings"}>Settings</a></li>
              <li>
                <.link href={~p"/users/log-out"} method="delete">Log out</.link>
              </li>
            </ul>
          </div>
        <% else %>
          <a href={~p"/users/log-in"} class="btn btn-ghost btn-sm">Log in</a>
          <a href={~p"/users/register"} class="btn btn-primary btn-sm">Register</a>
        <% end %>
      </div>
    </div>

    <main class="mf-content px-4 py-10 sm:px-6 lg:px-8">
      <div class="mx-auto max-w-[1400px] space-y-4">
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="footer footer-center p-6 bg-base-200 text-base-content/60 text-sm">
      <div class="flex flex-wrap justify-center gap-4">
        <a href="/privacy" class="link link-hover">Privacy Policy</a>
        <a href="/terms" class="link link-hover">Terms of Service</a>
        <a href="mailto:support@metric-flow.app" class="link link-hover">Contact</a>
      </div>
      <p>&copy; {Date.utc_today().year} MetricFlow. All rights reserved.</p>
    </footer>

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

  @doc """
  Provides dark vs light theme toggle.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="system">
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="light">
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button class="flex p-2 cursor-pointer w-1/3" phx-click={JS.dispatch("phx:set-theme")} data-phx-theme="dark">
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
