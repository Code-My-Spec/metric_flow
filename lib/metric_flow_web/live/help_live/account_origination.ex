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
    <div class="mf-content max-w-3xl mx-auto">
      <.header>
        How Account Origination Works
        <:subtitle>The four ways an account gets created or connected to another</:subtitle>
      </.header>

      <div class="mt-8 space-y-8 prose prose-sm max-w-none">
        <section>
          <h3>1. Self-registration</h3>
          <p>
            Anyone can register at <code>/users/register</code> with an email, password, and
            optionally an account name and type (Client or Agency). Submitting sends a
            confirmation email — the account isn't usable until that link is clicked — and, if an
            account name was given, creates a new account of the chosen type with the registrant
            as owner.
          </p>
        </section>

        <section>
          <h3>2. Domain auto-enrollment</h3>
          <p>
            If an agency has configured an auto-enrollment rule for an email domain, anyone who
            registers with an address on that domain is automatically added as a member of the
            agency's account, regardless of what they picked at signup.
          </p>
        </section>

        <section>
          <h3>3. Agency referral links</h3>
          <p>
            An agency account can generate a referral token meant to be shared as
            <code>/users/register?ref=&lt;token&gt;</code>. A customer who registers a Client
            account through that link is connected to the referring agency automatically: the
            agency gets read-only access, and the client account is marked
            <strong>Originated</strong> on the agency's Clients page.
          </p>
          <p class="text-base-content/60">
            Generate your agency's link from the <strong>Originate a Client</strong> button on the
            <.link navigate={~p"/app/agency/clients"} class="link">Clients</.link> page.
          </p>
        </section>

        <section>
          <h3>4. Email invitations</h3>
          <p>
            An owner or admin of an account can go to Accounts → Invitations and invite an email
            address to join their <em>current</em> account at a chosen role. This adds someone to
            an account you already have — it does not create a new client account. The invite
            link is valid for 7 days and can be used once; the recipient is sent to log in or
            register first if they don't already have an account, then returned to accept or
            decline. Accepting creates their membership and, if they belong to an agency
            themselves, extends that agency's access to the same account — this is what shows as
            <strong>Invited</strong> on the agency's Clients page.
          </p>
        </section>
      </div>
    </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "How Account Origination Works")}
  end
end
