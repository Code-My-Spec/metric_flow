defmodule MetricFlowWeb.AgencyLive.Settings do
  @moduledoc """
  Function component module that renders agency configuration sections within
  the AccountLive.Settings page.

  Renders auto-enrollment and white-label branding controls conditionally when
  the active account is a team account and the current user holds an owner or
  admin role. Non-team accounts and non-admin users see no output from this
  module.
  """

  use Phoenix.Component

  import MetricFlowWeb.CoreComponents, only: [input: 1]

  alias MetricFlow.Agencies.AutoEnrollmentRule
  alias MetricFlow.Agencies.WhiteLabelConfig

  # ---------------------------------------------------------------------------
  # Grant Agency Access section
  # ---------------------------------------------------------------------------

  @doc """
  Renders the Grant Agency Access section for client accounts.

  Allows account owners/admins to grant agency accounts access to their account
  and view/revoke existing agency grants.

  Expects the following assigns:
    - `agency_grants` — list of maps with agency grant data
    - `grant_agency_form` — a map with `:params` and `:errors` keys
    - `can_manage_agencies` — boolean, whether user can grant/revoke
  """
  attr :agency_grants, :list, required: true
  attr :grant_agency_form, :map, required: true
  attr :can_manage_agencies, :boolean, default: false

  def grant_agency_access_section(assigns) do
    ~H"""
    <section
      data-role="agency-access-grants"
      class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
    >
      <header class="space-y-1">
        <h2 class="text-lg font-semibold text-base-content">Agency Access</h2>
        <p class="text-sm text-base-content/70">
          Grant an agency access to this account by its slug. The agency's team members inherit the access level you pick.
        </p>
      </header>

      <div :if={@agency_grants != []} class="mt-4 space-y-2">
        <div
          :for={grant <- @agency_grants}
          class="flex flex-wrap items-center justify-between gap-3 rounded-box border border-neutral bg-base-100 p-3"
          data-role="agency-grant"
        >
          <div class="flex min-w-0 flex-wrap items-center gap-2">
            <span class="text-sm font-medium text-base-content break-words">
              {grant.agency_account_name}
            </span>
            <span class="text-xs text-base-content/60 font-mono break-all">
              ({grant.agency_account_slug})
            </span>
            <span class="badge badge-sm">{access_level_label(grant.access_level)}</span>
            <span :if={grant.origination_status == :originator} class="badge badge-primary badge-sm">
              Originator
            </span>
          </div>
          <button
            :if={@can_manage_agencies and grant.origination_status != :originator}
            type="button"
            class="rounded-box border border-error bg-base-200 px-3 py-1 text-xs font-semibold text-error hover:bg-base-300"
            data-role="revoke-agency-access"
            phx-click="revoke_agency_access"
            phx-value-agency-account-id={grant.agency_account_id}
          >
            Revoke
          </button>
        </div>
      </div>

      <p :if={@agency_grants == []} class="mt-4 text-sm text-base-content/60">
        No agencies have access to this account.
      </p>

      <form
        :if={@can_manage_agencies}
        id="grant-agency-access-form"
        phx-submit="grant_agency_access"
        class="mt-6 space-y-4"
      >
        <div class="space-y-1">
          <label for="agency-slug-input" class="block text-sm font-semibold text-base-content">
            Agency Account Slug
          </label>
          <input
            id="agency-slug-input"
            type="text"
            name="agency_access[slug]"
            data-role="agency-slug-input"
            value={Map.get(@grant_agency_form.params, "slug", "")}
            class={[
              "input input-bordered w-full font-mono bg-base-100 border-neutral rounded-box text-base-content",
              has_form_error?(@grant_agency_form, :slug) && "input-error"
            ]}
            placeholder="e.g., my-agency"
          />
          <p :if={has_form_error?(@grant_agency_form, :slug)} class="text-sm text-error">
            {first_form_error(@grant_agency_form, :slug)}
          </p>
        </div>

        <div class="space-y-1">
          <label for="agency-access-level" class="block text-sm font-semibold text-base-content">
            Access Level
          </label>
          <select
            id="agency-access-level"
            name="agency_access[access_level]"
            data-role="agency-access-level"
            class="select select-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
          >
            <option
              :for={level <- [:read_only, :account_manager, :admin]}
              value={level}
              selected={Map.get(@grant_agency_form.params, "access_level") == Atom.to_string(level)}
            >
              {access_level_label(level)}
            </option>
          </select>
        </div>

        <button
          type="submit"
          class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
        >
          Grant Access
        </button>
      </form>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # Auto-Enrollment section
  # ---------------------------------------------------------------------------

  @doc """
  Renders the Auto-Enrollment configuration section.

  Expects the following assigns:
    - `auto_enrollment_rule` — the current `AutoEnrollmentRule` struct or nil
    - `auto_enrollment_form` — a map with `:params` and `:errors` keys
  """
  attr :auto_enrollment_rule, :any, default: nil
  attr :auto_enrollment_form, :map, required: true

  def auto_enrollment_section(assigns) do
    ~H"""
    <section
      data-role="agency-auto-enrollment"
      class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
    >
      <header class="space-y-1">
        <h2 class="text-lg font-semibold text-base-content">Auto-Enrollment</h2>
        <p class="text-sm text-base-content/70">
          Automatically add new users to this account when they register with a matching email domain.
        </p>
      </header>

      <div :if={not is_nil(@auto_enrollment_rule)} class="mt-4 flex flex-wrap items-center gap-3">
        <span class="text-sm text-base-content break-all">
          {@auto_enrollment_rule.email_domain}
        </span>
        <%= if @auto_enrollment_rule.enabled do %>
          <span class="badge badge-success">Active</span>
          <button
            type="button"
            class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-xs text-base-content hover:bg-base-300"
            data-role="disable-auto-enrollment"
            phx-click="disable_auto_enrollment"
          >
            Disable
          </button>
        <% else %>
          <span class="badge badge-ghost">Disabled</span>
        <% end %>
      </div>

      <form id="auto-enrollment-form" phx-submit="save_auto_enrollment" class="mt-4 space-y-4">
        <div class="space-y-1">
          <label
            for="auto-enrollment-domain-input"
            class="block text-sm font-semibold text-base-content"
          >
            Email Domain
          </label>
          <input
            id="auto-enrollment-domain-input"
            type="text"
            name="auto_enrollment[domain]"
            data-role="auto-enrollment-domain-input"
            value={domain_value(@auto_enrollment_rule, @auto_enrollment_form)}
            class={[
              "input input-bordered w-full bg-base-100 border-neutral rounded-box text-base-content",
              has_form_error?(@auto_enrollment_form, :email_domain) && "input-error"
            ]}
            placeholder="e.g., myagency.com"
          />
          <p
            :if={has_form_error?(@auto_enrollment_form, :email_domain)}
            class="text-sm text-error"
          >
            {first_form_error(@auto_enrollment_form, :email_domain)}
          </p>
        </div>

        <div class="space-y-1">
          <label
            for="auto-enrollment-default-role"
            class="block text-sm font-semibold text-base-content"
          >
            Default Access Level
          </label>
          <select
            id="auto-enrollment-default-role"
            name="auto_enrollment[default_access_level]"
            data-role="auto-enrollment-default-role"
            class="select select-bordered w-full bg-base-100 border-neutral rounded-box text-base-content"
          >
            <option
              :for={level <- [:read_only, :account_manager, :admin]}
              value={level}
              selected={access_level_selected?(@auto_enrollment_rule, @auto_enrollment_form, level)}
            >
              {access_level_label(level)}
            </option>
          </select>
        </div>

        <button
          type="submit"
          class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
        >
          Enable Auto-Enrollment
        </button>
      </form>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # White-Label Branding section
  # ---------------------------------------------------------------------------

  @doc """
  Renders the White-Label Branding configuration section.

  Expects the following assigns:
    - `white_label_config` — the current `WhiteLabelConfig` struct or nil
    - `white_label_form` — a map with `:params` and `:errors` keys
  """
  attr :white_label_config, :any, default: nil
  attr :white_label_form, :map, required: true
  attr :logo_upload, :any, default: nil
  attr :pending_logo, :any, default: nil

  def white_label_section(assigns) do
    changeset =
      Ecto.Changeset.cast(
        assigns.white_label_config || %WhiteLabelConfig{},
        assigns.white_label_form.params,
        [:subdomain, :custom_domain, :logo_url, :primary_color, :secondary_color, :accent_color]
      )

    errors = assigns.white_label_form.errors
    changeset = %{changeset | errors: errors, valid?: errors == [], action: :validate}
    assigns = assign(assigns, :branding_form, to_form(changeset, as: :white_label))

    ~H"""
    <section
      data-role="agency-white-label"
      class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6"
    >
      <header class="space-y-1">
        <h2 class="text-lg font-semibold text-base-content">White-Label Branding</h2>
        <p class="text-sm text-base-content/70">
          Customize the logo, domain, and colors your clients see.
        </p>
      </header>

      <div
        :if={has_preview_data?(@white_label_form)}
        data-role="white-label-preview"
        class="mt-4 rounded-box border border-neutral bg-base-100 p-4"
      >
        <p class="text-xs text-base-content/60 mb-2">Preview</p>
        <div class="flex flex-wrap items-center gap-4">
          <img
            :if={preview_value(@white_label_form, :logo_url) != ""}
            id="branding-logo-url-preview"
            src={preview_value(@white_label_form, :logo_url)}
            alt="Agency logo preview"
            class="h-16 max-w-48 object-contain"
          />
          <div
            :if={preview_value(@white_label_form, :accent_color) != ""}
            id="branding-accent-preview"
            class="h-8 w-8 rounded-box"
            style={"background-color: #{preview_value(@white_label_form, :accent_color)}"}
            aria-label="Accent color preview"
          >
          </div>
          <div
            :if={preview_value(@white_label_form, :primary_color) != ""}
            class="w-8 h-8 rounded-box"
            style={"background-color: #{preview_value(@white_label_form, :primary_color)}"}
          >
          </div>
          <div
            :if={preview_value(@white_label_form, :secondary_color) != ""}
            class="w-8 h-8 rounded-box"
            style={"background-color: #{preview_value(@white_label_form, :secondary_color)}"}
          >
          </div>
          <span
            :if={preview_value(@white_label_form, :primary_color) != ""}
            class="text-xs font-mono text-base-content/80 break-all"
          >
            {preview_value(@white_label_form, :primary_color)}
          </span>
          <span
            :if={preview_value(@white_label_form, :secondary_color) != ""}
            class="text-xs font-mono text-base-content/80 break-all"
          >
            {preview_value(@white_label_form, :secondary_color)}
          </span>
        </div>
      </div>

      <.form
        for={@branding_form}
        id="white-label-form"
        phx-submit="save_white_label"
        phx-change="validate_white_label"
        class="mt-4 space-y-4"
      >
        <div
          :if={@logo_upload}
          id="branding-logo-upload"
          class="space-y-3 rounded-box border border-neutral bg-base-100 p-4"
        >
          <label for={@logo_upload.ref} class="block text-sm font-semibold text-base-content">
            Upload logo
          </label>
          <p class="text-sm text-base-content/60">PNG, JPG, or SVG. Maximum size 2 MB.</p>
          <.live_file_input upload={@logo_upload} class="block w-full text-sm text-base-content" />
          <%= for entry <- @logo_upload.entries do %>
            <div id={"logo-upload-#{entry.ref}"} class="space-y-2">
              <.live_img_preview entry={entry} class="h-16 max-w-48 object-contain" />
              <p class="text-sm text-base-content/70 break-all">{entry.client_name}</p>
              <progress
                value={entry.progress}
                max="100"
                aria-label="Logo upload progress"
                class="w-full"
              />
              <%= for error <- upload_errors(@logo_upload, entry) do %>
                <p role="alert" class="text-sm text-error">{logo_upload_error(error)}</p>
              <% end %>
            </div>
          <% end %>
          <%= for error <- upload_errors(@logo_upload) do %>
            <p role="alert" class="text-sm text-error">{logo_upload_error(error)}</p>
          <% end %>
          <div :if={@pending_logo} id="pending-logo-preview" class="space-y-2">
            <img
              src={@pending_logo.url}
              alt="Unsaved agency logo preview"
              class="h-16 max-w-48 object-contain"
            />
            <p class="text-sm text-base-content/60">
              Logo uploaded. Save your branding to apply it.
            </p>
          </div>
        </div>
        <.input
          field={@branding_form[:subdomain]}
          id="branding-subdomain"
          type="text"
          label="Subdomain"
        />
        <.input
          field={@branding_form[:custom_domain]}
          id="branding-custom-domain"
          type="text"
          label="Custom Domain"
        />
        <.input
          field={@branding_form[:logo_url]}
          id="branding-logo-url"
          type="text"
          label="Logo URL"
        />
        <.input
          field={@branding_form[:primary_color]}
          id="branding-primary-color"
          type="text"
          label="Primary Color"
        />
        <.input
          field={@branding_form[:secondary_color]}
          id="branding-secondary-color"
          type="text"
          label="Secondary Color"
        />
        <.input
          field={@branding_form[:accent_color]}
          id="branding-accent-color"
          type="text"
          label="Accent Color"
        />
        <div class="flex flex-wrap justify-end gap-2">
          <button
            :if={not is_nil(@white_label_config)}
            type="button"
            id="reset-branding"
            class="rounded-box border border-neutral bg-base-200 px-4 py-2 text-sm text-base-content hover:bg-base-300"
            data-role="reset-white-label"
            phx-click="reset_white_label"
          >
            Reset to Default
          </button>
          <button
            id="save-branding"
            type="submit"
            phx-disable-with="Saving…"
            class="btn-brand-gradient w-full rounded-box px-4 py-2 text-sm font-semibold sm:w-auto"
          >
            Save Branding
          </button>
        </div>
      </.form>

      <div
        :if={has_domain_config?(@white_label_config)}
        class="mt-4 rounded-box border border-neutral bg-base-100 p-4"
        data-role="dns-verification"
      >
        <h3 class="text-sm font-semibold text-base-content mb-2">DNS Configuration</h3>
        <p class="text-sm text-base-content/70 mb-3">
          Configure CNAME records pointing to <span class="font-mono">app.metricflow.io</span>.
        </p>

        <div
          :if={is_binary(@white_label_config.subdomain) and @white_label_config.subdomain != ""}
          class="flex flex-wrap items-center gap-3 mb-2"
        >
          <span class="font-mono text-sm text-base-content break-all">
            {@white_label_config.subdomain}.metric-flow.app
          </span>
          <%= if @white_label_config.subdomain_verified_at do %>
            <span class="badge badge-success badge-sm">Verified</span>
          <% else %>
            <span class="badge badge-warning badge-sm">Pending</span>
          <% end %>
        </div>

        <div
          :if={
            is_binary(@white_label_config.custom_domain) and @white_label_config.custom_domain != ""
          }
          class="flex flex-wrap items-center gap-3 mb-2"
        >
          <span class="font-mono text-sm text-base-content break-all">
            {@white_label_config.custom_domain}
          </span>
          <%= if @white_label_config.custom_domain_verified_at do %>
            <span class="badge badge-success badge-sm">Verified</span>
          <% else %>
            <span class="badge badge-warning badge-sm">Pending</span>
          <% end %>
        </div>

        <button
          type="button"
          class="rounded-box border border-neutral bg-base-200 px-3 py-1 text-xs text-base-content hover:bg-base-300 mt-1"
          data-role="verify-dns"
          phx-click="verify_dns"
        >
          Verify DNS
        </button>
      </div>
    </section>
    """
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp domain_value(%AutoEnrollmentRule{email_domain: domain}, _form) when not is_nil(domain),
    do: domain

  defp domain_value(nil, form), do: Map.get(form.params, "domain", "")

  defp access_level_selected?(%AutoEnrollmentRule{default_access_level: level}, _form, option),
    do: level == option

  defp access_level_selected?(nil, form, option) do
    param = Map.get(form.params, "default_access_level")
    param == Atom.to_string(option) or (is_nil(param) and option == :read_only)
  end

  defp has_form_error?(form, field) do
    form
    |> Map.get(:errors, [])
    |> Keyword.has_key?(field)
  end

  defp first_form_error(form, field) do
    case form |> Map.get(:errors, []) |> Keyword.get(field) do
      {msg, _opts} -> msg
      nil -> nil
    end
  end

  defp logo_upload_error(:too_large), do: "Choose a logo smaller than 2 MB."
  defp logo_upload_error(:too_many_files), do: "Choose one logo at a time."
  defp logo_upload_error(:not_accepted), do: "Choose a PNG, JPG, or SVG logo."
  defp logo_upload_error(_error), do: "The logo could not be uploaded. Please try again."

  defp has_preview_data?(form) do
    params = Map.get(form, :params, %{})

    Enum.any?(["logo_url", "primary_color", "secondary_color", "accent_color"], fn key ->
      value = Map.get(params, key, "")
      is_binary(value) and value != ""
    end)
  end

  defp preview_value(form, field) do
    Map.get(form.params, Atom.to_string(field), "")
  end

  defp has_domain_config?(nil), do: false

  defp has_domain_config?(config) do
    has_subdomain = is_binary(config.subdomain) and config.subdomain != ""
    has_custom = is_binary(config.custom_domain) and config.custom_domain != ""
    has_subdomain or has_custom
  end

  defp access_level_label(:read_only), do: "Read Only"
  defp access_level_label(:account_manager), do: "Account Manager"
  defp access_level_label(:admin), do: "Admin"
end
