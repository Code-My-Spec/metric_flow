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
    <div data-role="agency-access-grants" class="card bg-base-100 shadow mf-card">
      <div class="card-body">
        <h2 class="card-title text-base">Agency Access</h2>
        <p class="text-sm text-base-content/60">
          Grant agencies access to manage this account. The agency's team members will inherit access.
        </p>

        <%!-- Current grants list --%>
        <div :if={@agency_grants != []} class="mt-4 space-y-2">
          <div
            :for={grant <- @agency_grants}
            class="flex items-center justify-between p-3 rounded bg-base-200/50 border border-base-300"
            data-role="agency-grant"
          >
            <div class="flex items-center gap-3">
              <div>
                <span class="font-medium text-sm">{grant.agency_account_name}</span>
                <span class="text-xs text-base-content/50 font-mono ml-1">({grant.agency_account_slug})</span>
              </div>
              <span class="badge badge-sm">{access_level_label(grant.access_level)}</span>
              <span :if={grant.origination_status == :originator} class="badge badge-primary badge-sm">Originator</span>
            </div>
            <button
              :if={@can_manage_agencies and grant.origination_status != :originator}
              type="button"
              class="btn btn-ghost btn-sm text-error"
              data-role="revoke-agency-access"
              phx-click="revoke_agency_access"
              phx-value-agency-account-id={grant.agency_account_id}
            >
              Revoke
            </button>
          </div>
        </div>

        <div :if={@agency_grants == []} class="mt-4">
          <p class="text-sm text-base-content/40">No agencies have access to this account.</p>
        </div>

        <%!-- Grant form (owners/admins only) --%>
        <form :if={@can_manage_agencies} id="grant-agency-access-form" phx-submit="grant_agency_access" class="space-y-4 mt-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">Agency Account Slug</span>
            </label>
            <input
              type="text"
              name="agency_access[slug]"
              data-role="agency-slug-input"
              value={Map.get(@grant_agency_form.params, "slug", "")}
              class={["input w-full font-mono", has_form_error?(@grant_agency_form, :slug) && "input-error"]}
              placeholder="e.g., my-agency"
            />
            <p :if={has_form_error?(@grant_agency_form, :slug)} class="text-sm text-error mt-1">
              {first_form_error(@grant_agency_form, :slug)}
            </p>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Access Level</span>
            </label>
            <select
              name="agency_access[access_level]"
              data-role="agency-access-level"
              class="select w-full"
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

          <div class="card-actions justify-end">
            <button type="submit" class="btn btn-primary w-full sm:w-auto">
              Grant Access
            </button>
          </div>
        </form>
      </div>
    </div>
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
    <div data-role="agency-auto-enrollment" class="card bg-base-100 shadow mf-card">
      <div class="card-body">
        <h2 class="card-title text-base">Auto-Enrollment</h2>
        <p class="text-sm text-base-content/60">
          Automatically add new users to this account when they register with a matching email domain.
        </p>

        <%!-- Active rule status display --%>
        <div :if={not is_nil(@auto_enrollment_rule)} class="flex items-center gap-3 mt-2">
          <span class="text-sm">
            {@auto_enrollment_rule.email_domain}
          </span>
          <%= if @auto_enrollment_rule.enabled do %>
            <span class="badge badge-success">Active</span>
            <button
              type="button"
              class="btn btn-ghost btn-sm"
              data-role="disable-auto-enrollment"
              phx-click="disable_auto_enrollment"
            >
              Disable
            </button>
          <% else %>
            <span class="badge badge-ghost">Disabled</span>
          <% end %>
        </div>

        <form id="auto-enrollment-form" phx-submit="save_auto_enrollment" class="space-y-4 mt-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">Email Domain</span>
            </label>
            <input
              type="text"
              name="auto_enrollment[domain]"
              data-role="auto-enrollment-domain-input"
              value={domain_value(@auto_enrollment_rule, @auto_enrollment_form)}
              class={["input w-full", has_form_error?(@auto_enrollment_form, :email_domain) && "input-error"]}
              placeholder="e.g., myagency.com"
            />
            <p
              :if={has_form_error?(@auto_enrollment_form, :email_domain)}
              class="text-sm text-error mt-1"
            >
              {first_form_error(@auto_enrollment_form, :email_domain)}
            </p>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Default Access Level</span>
            </label>
            <select
              name="auto_enrollment[default_access_level]"
              data-role="auto-enrollment-default-role"
              class="select w-full"
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

          <div class="card-actions justify-end">
            <button type="submit" class="btn btn-primary w-full sm:w-auto">
              Enable Auto-Enrollment
            </button>
          </div>
        </form>
      </div>
    </div>
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

  def white_label_section(assigns) do
    ~H"""
    <div data-role="agency-white-label" class="card bg-base-100 shadow mf-card">
      <div class="card-body">
        <h2 class="card-title text-base">White-Label Branding</h2>
        <p class="text-sm text-base-content/60">
          Customize the branding shown to your clients.
        </p>

        <%!-- Preview section: reflects live changes before saving --%>
        <div
          :if={has_preview_data?(@white_label_form)}
          data-role="white-label-preview"
          class="mt-4 p-4 rounded bg-base-200/50 border border-base-300"
        >
          <p class="text-xs text-base-content/50 mb-2">Preview</p>
          <div class="flex items-center gap-4">
            <div
              :if={preview_value(@white_label_form, :primary_color) != ""}
              class="w-8 h-8 rounded"
              style={"background-color: #{preview_value(@white_label_form, :primary_color)}"}
            >
            </div>
            <div
              :if={preview_value(@white_label_form, :secondary_color) != ""}
              class="w-8 h-8 rounded"
              style={"background-color: #{preview_value(@white_label_form, :secondary_color)}"}
            >
            </div>
            <span :if={preview_value(@white_label_form, :primary_color) != ""} class="text-xs font-mono">
              {preview_value(@white_label_form, :primary_color)}
            </span>
            <span :if={preview_value(@white_label_form, :secondary_color) != ""} class="text-xs font-mono">
              {preview_value(@white_label_form, :secondary_color)}
            </span>
          </div>
        </div>

        <form id="white-label-form" phx-submit="save_white_label" phx-change="validate_white_label" class="space-y-4 mt-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">Subdomain</span>
            </label>
            <input
              type="text"
              name="white_label[subdomain]"
              value={white_label_value(@white_label_config, @white_label_form, :subdomain)}
              class={["input w-full font-mono", has_form_error?(@white_label_form, :subdomain) && "input-error"]}
            />
            <p class="text-xs text-base-content/50 mt-1">
              Lowercase letters, numbers, and hyphens only (3–63 characters).
            </p>
            <p
              :if={has_form_error?(@white_label_form, :subdomain)}
              class="text-sm text-error mt-1"
            >
              {first_form_error(@white_label_form, :subdomain)}
            </p>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Logo URL</span>
            </label>
            <input
              type="text"
              name="white_label[logo_url]"
              value={white_label_value(@white_label_config, @white_label_form, :logo_url)}
              class={["input w-full", has_form_error?(@white_label_form, :logo_url) && "input-error"]}
            />
            <p
              :if={has_form_error?(@white_label_form, :logo_url)}
              class="text-sm text-error mt-1"
            >
              {first_form_error(@white_label_form, :logo_url)}
            </p>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Primary Color</span>
            </label>
            <input
              type="text"
              name="white_label[primary_color]"
              value={white_label_value(@white_label_config, @white_label_form, :primary_color)}
              class={["input w-full font-mono", has_form_error?(@white_label_form, :primary_color) && "input-error"]}
              placeholder="#RRGGBB"
            />
            <p
              :if={has_form_error?(@white_label_form, :primary_color)}
              class="text-sm text-error mt-1"
            >
              {first_form_error(@white_label_form, :primary_color)}
            </p>
          </div>

          <div class="form-control">
            <label class="label">
              <span class="label-text">Secondary Color</span>
            </label>
            <input
              type="text"
              name="white_label[secondary_color]"
              value={white_label_value(@white_label_config, @white_label_form, :secondary_color)}
              class={["input w-full font-mono", has_form_error?(@white_label_form, :secondary_color) && "input-error"]}
              placeholder="#RRGGBB"
            />
            <p
              :if={has_form_error?(@white_label_form, :secondary_color)}
              class="text-sm text-error mt-1"
            >
              {first_form_error(@white_label_form, :secondary_color)}
            </p>
          </div>

          <div class="card-actions justify-end gap-2">
            <button
              :if={not is_nil(@white_label_config)}
              type="button"
              class="btn btn-ghost btn-sm"
              data-role="reset-white-label"
              phx-click="reset_white_label"
            >
              Reset to Default
            </button>
            <button type="submit" class="btn btn-primary w-full sm:w-auto">
              Save Branding
            </button>
          </div>
        </form>

        <%!-- DNS verification section: shown when a subdomain is configured --%>
        <div
          :if={not is_nil(@white_label_config) and is_binary(@white_label_config.subdomain) and @white_label_config.subdomain != ""}
          class="mt-4 p-4 rounded border border-warning/40 bg-warning/5"
          data-role="dns-verification"
        >
          <h3 class="text-sm font-semibold mb-2">DNS Verification Required</h3>
          <p class="text-sm text-base-content/60 mb-2">
            To activate your custom subdomain <span class="font-mono font-medium">{@white_label_config.subdomain}</span>,
            configure a CNAME record pointing to <span class="font-mono">app.metricflow.io</span>.
          </p>
          <div class="flex items-center gap-3">
            <span class="badge badge-warning badge-sm">Pending verification</span>
            <button
              type="button"
              class="btn btn-ghost btn-sm"
              data-role="verify-dns"
              phx-click="verify_dns"
            >
              Verify DNS
            </button>
          </div>
        </div>
      </div>
    </div>
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

  defp white_label_value(config, form, field) do
    form_value = Map.get(form.params, Atom.to_string(field), "")

    if form_value != "" do
      form_value
    else
      case config do
        %WhiteLabelConfig{} -> Map.get(config, field) || ""
        nil -> ""
      end
    end
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

  defp has_preview_data?(form) do
    params = Map.get(form, :params, %{})

    Enum.any?(["primary_color", "secondary_color"], fn key ->
      value = Map.get(params, key, "")
      is_binary(value) and value != ""
    end)
  end

  defp preview_value(form, field) do
    Map.get(form.params, Atom.to_string(field), "")
  end

  defp access_level_label(:read_only), do: "Read Only"
  defp access_level_label(:account_manager), do: "Account Manager"
  defp access_level_label(:admin), do: "Admin"
end
