defmodule MetricFlowWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use MetricFlowWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :white_label_config, :map, default: nil, doc: "optional agency white-label configuration"

  attr :active_account_name, :string,
    default: nil,
    doc: "the name of the currently active account, shown in the navbar"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <%= if @white_label_config do %>
      <style>
        :root {
          --wl-primary: <%= @white_label_config[:primary_color] || @white_label_config["primary_color"] %>;
          --wl-secondary: <%= @white_label_config[:secondary_color] || @white_label_config["secondary_color"] %>;
        }
      </style>
    <% end %>
    <div
      class="navbar mf-topnav px-4 sm:px-6 lg:px-8"
      data-white-label={if @white_label_config, do: "true"}
    >
      <div class="navbar-start">
        <div class="dropdown">
          <div tabindex="0" role="button" class="btn btn-ghost lg:hidden">
            <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" />
            </svg>
          </div>
          <ul tabindex="-1" class="menu menu-sm dropdown-content bg-base-200 rounded-box z-10 mt-3 w-52 p-2 shadow">
            <%= if @current_scope do %>
              <li><a href={~p"/integrations"}>Integrations</a></li>
              <li><a href={~p"/correlations"}>Correlations</a></li>
              <li><a href={~p"/insights"}>Insights</a></li>
              <li><a href={~p"/chat"}>Chat</a></li>
              <li><a href={~p"/visualizations"}>Visualizations</a></li>
              <li><a href={~p"/accounts"}>Accounts</a></li>
              <li><a href={~p"/accounts/members"}>Members</a></li>
            <% end %>
          </ul>
        </div>
        <%= if @white_label_config && (@white_label_config[:logo_url] || @white_label_config["logo_url"]) do %>
          <a href="/" class="btn btn-ghost">
            <img
              src={@white_label_config[:logo_url] || @white_label_config["logo_url"]}
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
      <div class="navbar-center hidden lg:flex">
        <%= if @current_scope do %>
          <ul class="menu menu-horizontal px-1">
            <li><a href={~p"/integrations"}>Integrations</a></li>
            <li><a href={~p"/correlations"}>Correlations</a></li>
            <li><a href={~p"/insights"}>Insights</a></li>
            <li><a href={~p"/chat"}>Chat</a></li>
            <li><a href={~p"/visualizations"}>Visualizations</a></li>
            <li><a href={~p"/accounts"}>Accounts</a></li>
            <li><a href={~p"/accounts/members"}>Members</a></li>
          </ul>
        <% end %>
      </div>
      <div class="navbar-end gap-2">
        <%= if @active_account_name do %>
          <span data-role="current-account-name" class="text-sm text-base-content/70 hidden sm:inline">
            {@active_account_name}
          </span>
        <% end %>
        <%= if @current_scope do %>
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
              <li><a href={~p"/users/settings"}>Settings</a></li>
              <li>
                <a href={~p"/users/log-out"} method="delete">Log out</a>
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
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
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
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        class="flex p-2 cursor-pointer w-1/3"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
