defmodule MetricFlowWeb.HelpLive.AccountOrigination do
  @moduledoc """
  Explains how accounts get created and connected to each other: self-registration,
  domain auto-enrollment, agency referral links, and email invitations.
  """

  use MetricFlowWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      white_label_config={assigns[:white_label_config]}
      active_account_name={assigns[:active_account_name]}
      active_account_type={assigns[:active_account_type]}
    >
      <main
        data-role="help-account-origination-root"
        class="mx-auto w-full max-w-2xl space-y-6 overflow-x-hidden"
      >
        <header class="space-y-2">
          <p class="text-xs font-semibold uppercase tracking-wide text-base-content/60">
            Help
          </p>
          <h1 class="text-2xl font-semibold text-base-content break-words">
            How Account Origination Works
          </h1>
          <p class="text-sm text-base-content/70 break-words">
            The four ways an account gets created or connected to another.
          </p>
        </header>

        <article
          data-role="help-origination-self-registration"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6 space-y-3"
        >
          <h2 class="text-lg font-semibold text-base-content break-words">
            1. Self-registration
          </h2>
          <p class="text-sm leading-relaxed text-base-content/80 break-words">
            Anyone can register at
            <code class="rounded-box bg-base-300 px-1.5 py-0.5 font-mono text-xs text-base-content break-all">
              /users/register
            </code>
            with an email, password, and optionally an account name and type
            (Client or Agency). Submitting sends a confirmation email — the
            account isn't usable until that link is clicked — and, if an account
            name was given, creates a new account of the chosen type with the
            registrant as owner.
          </p>
        </article>

        <article
          data-role="help-origination-domain-auto-enrollment"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6 space-y-3"
        >
          <h2 class="text-lg font-semibold text-base-content break-words">
            2. Domain auto-enrollment
          </h2>
          <p class="text-sm leading-relaxed text-base-content/80 break-words">
            If an agency has configured an auto-enrollment rule for an email
            domain, anyone who registers with an address on that domain is
            automatically added as a member of the agency's account, regardless
            of what they picked at signup.
          </p>
        </article>

        <article
          data-role="help-origination-referral-links"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6 space-y-3"
        >
          <h2 class="text-lg font-semibold text-base-content break-words">
            3. Agency referral links
          </h2>
          <p class="text-sm leading-relaxed text-base-content/80 break-words">
            An agency account can generate a referral token meant to be shared as <code class="rounded-box bg-base-300 px-1.5 py-0.5 font-mono text-xs text-base-content break-all">/users/register?ref=&lt;token&gt;</code>. A customer who registers a Client account through that
            link is connected to the referring agency automatically: the agency
            gets read-only access, and the client account is marked
            <strong class="text-base-content">Originated</strong>
            on the agency's Clients page.
          </p>
          <p class="text-sm leading-relaxed text-base-content/70 break-words">
            Generate your agency's link from the <strong class="text-base-content">Add Client</strong>
            button on the
            <.link
              navigate={~p"/app/agency/clients"}
              data-role="help-origination-clients-link"
              class="text-primary underline hover:no-underline"
            >
              Clients
            </.link>
            page.
          </p>
        </article>

        <article
          data-role="help-origination-email-invitations"
          class="rounded-box border border-neutral bg-base-200 p-4 sm:p-6 space-y-3"
        >
          <h2 class="text-lg font-semibold text-base-content break-words">
            4. Email invitations
          </h2>
          <p class="text-sm leading-relaxed text-base-content/80 break-words">
            An owner or admin of an account can go to Accounts → Invitations and
            invite an email address to join their <em>current</em>
            account at a chosen role. This adds someone to an account you
            already have — it does not create a new client account. The invite
            link is valid for 7 days and can be used once; the recipient is sent
            to log in or register first if they don't already have an account,
            then returned to accept or decline. Accepting creates their
            membership and, if they belong to an agency themselves, extends that
            agency's access to the same account — this is what shows as
            <strong class="text-base-content">Invited</strong>
            on the agency's Clients page.
          </p>
        </article>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "How Account Origination Works")}
  end
end
