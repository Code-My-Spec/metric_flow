defmodule MetricFlow.Onboarding.Tools do
  @moduledoc """
  Agent tools for data-source setup, defined once and served two ways:

    * the in-app chat agent (`alloy_tools/1`, `:chat` mode) acting on the
      chat's active account (the scope's `account_id`);
    * the MCP endpoint (`:mcp` mode) acting as the OAuth token's user, on any
      account they are a member of (own accounts and agency client accounts).
      `list_accounts` lists them; every other tool takes `account_id`, which
      may be left out only when the user belongs to exactly one account.

  Reads need membership; writes (`save_sync_selection`, `sync_now`,
  `disconnect_product`) need an owner, admin or account_manager role.

  An agent can't finish an OAuth consent screen — only the customer can. So
  the connect tool returns a link for the customer to open, and every other
  tool works once they've connected.

  Each spec is `%{name, description, input_schema, run}` (plus `write: true`
  for tools that change data) where `run` is
  `(args, %{scope: Scope.t()}) -> {:ok, map()} | {:error, String.t()}`.
  """

  alias MetricFlow.AccountAccess
  alias MetricFlow.Agencies
  alias MetricFlow.Invitations.InvitationNotifier
  alias MetricFlow.Onboarding
  alias MetricFlow.Users.Scope
  alias MetricFlow.Users.User

  @connection_enum ["google", "youtube", "facebook_ads", "quickbooks"]
  @product_enum ~w(google_analytics google_ads google_search_console google_business youtube facebook_ads quickbooks)

  @account_prop %{
    account_id: %{
      type: "integer",
      description:
        "Account to act on (from list_accounts). Optional only when you belong to one account."
    }
  }

  @doc "Tool specs for a mode: `:chat` (active account) or `:mcp` (account per call)."
  @spec specs(:chat | :mcp) :: [map()]
  def specs(:chat), do: base_specs()

  def specs(:mcp),
    do: [list_accounts_spec(), invite_client_spec() | Enum.map(base_specs(), &with_account/1)]

  @doc """
  Runs a tool by name. In `:chat` mode `ctx` carries `:scope`; in `:mcp` mode
  it carries `:user` and the scope is resolved from `account_id` in `args`.
  """
  @spec call(:chat | :mcp, String.t(), map(), map()) :: {:ok, map()} | {:error, String.t()}
  def call(mode, name, args, ctx) do
    args = args || %{}

    with {:ok, spec} <- find_spec(mode, name),
         :ok <- check_required(spec, args),
         {:ok, ctx} <- resolve_scope(mode, spec, args, ctx),
         :ok <- check_write(spec, ctx) do
      spec.run.(args, ctx)
    end
  end

  @doc """
  The chat tools as Alloy inline tools: on an agency account, the `:mcp` tools
  run as the scope's user (so the agency can act on its clients); otherwise the
  `:chat` tools acting on the scope's account.
  """
  @spec alloy_tools(Scope.t()) :: [Alloy.Tool.Inline.t()]
  def alloy_tools(%Scope{} = scope) do
    if agency?(scope),
      do: inline_tools(:mcp, %{user: scope.user}),
      else: inline_tools(:chat, %{scope: scope})
  end

  @doc "True when the scope's active account is an agency account the user belongs to."
  @spec agency?(Scope.t()) :: boolean()
  def agency?(%Scope{user: %User{id: user_id}} = scope) do
    account_id = AccountAccess.account_id(scope)
    Enum.any?(AccountAccess.memberships(user_id), &(&1.id == account_id and &1.type == :agency))
  end

  def agency?(_scope), do: false

  defp inline_tools(mode, ctx) do
    Enum.map(specs(mode), fn spec ->
      Alloy.Tool.inline(
        name: spec.name,
        description: spec.description,
        input_schema: spec.input_schema,
        concurrent?: false,
        execute: fn input, _alloy_ctx ->
          case call(mode, spec.name, input, ctx) do
            {:ok, data} -> {:ok, Jason.encode!(data)}
            {:error, message} -> {:error, message}
          end
        end
      )
    end)
  end

  # ---------------------------------------------------------------------------
  # Specs
  # ---------------------------------------------------------------------------

  defp base_specs do
    [
      %{
        name: "get_setup_status",
        description:
          "Show which data sources are connected and what each is set to sync. Call this first. " <>
            "Connections are Google (Analytics, Ads, Search Console, Business Profile under one sign-in), " <>
            "YouTube (its own sign-in), Meta (Facebook/Instagram ads) and QuickBooks. Product status " <>
            "is one of: not_connected, not_granted (Google connected but that product unticked on " <>
            "Google's consent screen — reconnect Google and tick it), reconnect (token expired), " <>
            "needs_selection, ready.",
        input_schema: object(%{}),
        run: fn _args, %{scope: scope} -> {:ok, %{connections: render_status(scope)}} end
      },
      %{
        name: "get_connect_link",
        description:
          "Get the link the customer must open to connect a data source (only the customer can " <>
            "complete the provider's consent screen). One Google link covers Analytics, Ads, Search " <>
            "Console and Business Profile; YouTube has its own link. " <>
            "After they connect, call get_setup_status, then list_sync_options.",
        input_schema:
          object(%{connection: %{type: "string", enum: @connection_enum}}, ["connection"]),
        run: fn %{"connection" => c}, %{scope: scope} ->
          with {:ok, key} <- parse(c, @connection_enum) do
            {:ok,
             %{
               connection: c,
               url: MetricFlowWeb.Endpoint.url() <> connect_path(key, scope),
               note: "The customer must be signed in to MetricFlow when they open this link."
             }}
          end
        end
      },
      %{
        name: "list_sync_options",
        description:
          "List what a connected product can sync, live from the provider: GA4 properties, " <>
            "Google Ads accounts, Search Console sites, Business Profile locations, YouTube " <>
            "channels, Meta ad accounts or QuickBooks income accounts. Returns ids to pass to " <>
            "save_sync_selection.",
        input_schema: object(%{product: %{type: "string", enum: @product_enum}}, ["product"]),
        run: fn %{"product" => p}, %{scope: scope} ->
          with {:ok, product} <- parse(p, @product_enum),
               {:ok, options} <- wrap(Onboarding.list_options(scope, product)) do
            info = Onboarding.product_info(product)

            {:ok,
             %{
               product: p,
               selection:
                 if(info.mode == :single, do: "pick exactly one", else: "pick one or more"),
               options: options
             }}
          end
        end
      },
      %{
        name: "save_sync_selection",
        write: true,
        description:
          "Choose what a product syncs and start its first sync. Pass ids from list_sync_options. " <>
            "Single-selection products (GA4, Google Ads, Search Console, Meta Ads) take exactly one id. " <>
            "Confirm the choice with the customer before saving when more than one option exists.",
        input_schema:
          object(
            %{
              product: %{type: "string", enum: @product_enum},
              ids: %{type: "array", items: %{type: "string"}, minItems: 1}
            },
            ["product", "ids"]
          ),
        run: fn %{"product" => p, "ids" => ids}, %{scope: scope} ->
          with {:ok, product} <- parse(p, @product_enum),
               {:ok, result} <- wrap(Onboarding.save_selection(scope, product, List.wrap(ids))) do
            {:ok, %{product: p, selected: result.selected, sync: to_string(result.sync)}}
          end
        end
      },
      %{
        name: "sync_now",
        write: true,
        description: "Queue a fresh sync for a product that is already set up (status ready).",
        input_schema: object(%{product: %{type: "string", enum: @product_enum}}, ["product"]),
        run: fn %{"product" => p}, %{scope: scope} ->
          with {:ok, product} <- parse(p, @product_enum),
               {:ok, result} <- wrap(Onboarding.sync_now(scope, product)) do
            {:ok, %{product: p, sync_job_id: result.sync_job_id, status: "queued"}}
          end
        end
      },
      %{
        name: "disconnect_product",
        write: true,
        description:
          "Disconnect one product, or \"google\" for the whole Google sign-in. Destructive: " <>
            "syncing stops. A single Google product just stops syncing (pick again to resume); " <>
            "disconnecting Google or any other product means the customer must reconnect. " <>
            "Only do this when the customer asked for it.",
        input_schema:
          object(%{product: %{type: "string", enum: ["google" | @product_enum]}}, ["product"]),
        run: fn %{"product" => p}, %{scope: scope} ->
          with {:ok, product} <- parse(p, ["google" | @product_enum]),
               :ok <- wrap_ok(Onboarding.disconnect(scope, product)) do
            {:ok, %{product: p, disconnected: true}}
          end
        end
      }
    ]
  end

  defp list_accounts_spec do
    %{
      name: "list_accounts",
      description:
        "List every account you can act on — your own and agency client accounts — with your " <>
          "role and a one-line data-source setup summary. Pass an id as account_id to other tools. " <>
          "Read-only roles can check status but not change syncs.",
      input_schema: object(%{}),
      run: fn _args, %{user: user} ->
        accounts =
          Enum.map(AccountAccess.memberships(user.id), fn account ->
            scope = Scope.put_account_id(Scope.for_user(user), account.id)

            Map.merge(account, %{
              can_change_setup: account.role in AccountAccess.write_roles(),
              setup: setup_summary(scope)
            })
          end)

        {:ok, %{accounts: accounts}}
      end
    }
  end

  defp invite_client_spec do
    %{
      name: "invite_client",
      description:
        "Get your agency's signup link for a new client and, given their email, email it to them. " <>
          "The client appears in list_accounts once they sign up with an account name; then use " <>
          "get_connect_link with that account_id. agency_account_id is optional when you are on " <>
          "one agency account.",
      input_schema:
        object(%{
          email: %{type: "string", description: "Client's email (optional)."},
          agency_account_id: %{type: "integer", description: "Agency account to invite to."}
        }),
      run: fn args, %{user: user} ->
        with {:ok, agency} <- pick_agency(user, args["agency_account_id"]),
             {:ok, token} <- referral_token(user, agency.id) do
          url = MetricFlowWeb.Endpoint.url() <> "/users/register?ref=" <> token
          email_client(args["email"], agency.name, url)
        end
      end
    }
  end

  defp pick_agency(user, id) do
    agencies = Enum.filter(AccountAccess.memberships(user.id), &(&1.type == :agency))

    case {agencies, id} do
      {[], _} ->
        {:error, "You are not on an agency account."}

      {[agency], nil} ->
        {:ok, agency}

      {_, nil} ->
        {:error,
         "You are on several agency accounts — pass agency_account_id, one of: " <>
           Enum.map_join(agencies, ", ", &"#{&1.id} (#{&1.name})") <> "."}

      {_, id} ->
        case Enum.find(agencies, &(to_string(&1.id) == to_string(id))) do
          nil -> {:error, "You are not on agency account #{id}."}
          agency -> {:ok, agency}
        end
    end
  end

  defp referral_token(user, agency_id) do
    case Agencies.generate_referral_link(
           Scope.put_account_id(Scope.for_user(user), agency_id),
           agency_id
         ) do
      {:ok, token} ->
        {:ok, token}

      {:error, _} ->
        {:error, "Not authorized: inviting clients needs an owner or admin role on the agency."}
    end
  end

  defp email_client(email, _agency_name, url) when email in [nil, ""],
    do: {:ok, %{url: url, emailed: false}}

  defp email_client(email, agency_name, url) when is_binary(email) do
    with true <- String.contains?(email, "@"),
         {:ok, _} <- InvitationNotifier.deliver_client_invite(email, agency_name, url) do
      {:ok, %{url: url, emailed: true}}
    else
      false ->
        {:error, "#{inspect(email)} is not an email address."}

      {:error, _} ->
        {:error, "Could not send the email. Here is the link to share instead: #{url}"}
    end
  end

  defp email_client(email, _agency_name, _url),
    do: {:error, "#{inspect(email)} is not an email address."}

  defp with_account(spec) do
    %{
      spec
      | input_schema: %{
          spec.input_schema
          | properties: Map.merge(@account_prop, spec.input_schema.properties)
        }
    }
  end

  defp setup_summary(scope) do
    Enum.map_join(Onboarding.status(scope), "; ", fn conn ->
      ready = Enum.count(conn.products, &(&1.status == :ready))

      "#{conn.name}: #{String.replace(to_string(conn.state), "_", " ")} (#{ready}/#{length(conn.products)} ready)"
    end)
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp find_spec(mode, name) do
    case Enum.find(specs(mode), &(&1.name == name)) do
      nil -> {:error, "Unknown tool #{name}."}
      spec -> {:ok, spec}
    end
  end

  defp check_required(spec, args) do
    case Enum.reject(spec.input_schema.required, &(args[&1] not in [nil, "", []])) do
      [] -> :ok
      missing -> {:error, "Missing required argument(s): #{Enum.join(missing, ", ")}."}
    end
  end

  defp resolve_scope(_mode, %{name: name}, _args, %{user: %User{}} = ctx)
       when name in ["list_accounts", "invite_client"],
       do: {:ok, ctx}

  defp resolve_scope(:chat, _spec, _args, %{scope: %Scope{user: %User{}}} = ctx), do: {:ok, ctx}

  defp resolve_scope(:mcp, _spec, args, %{user: %User{} = user} = ctx) do
    with {:ok, account_id} <- pick_account(user, args["account_id"]) do
      {:ok, Map.put(ctx, :scope, Scope.put_account_id(Scope.for_user(user), account_id))}
    end
  end

  defp resolve_scope(_mode, _spec, _args, _ctx), do: {:error, "Not signed in."}

  defp pick_account(user, nil) do
    case AccountAccess.memberships(user.id) do
      [%{id: id}] ->
        {:ok, id}

      [] ->
        {:error, "You are not a member of any account."}

      _ ->
        {:error, "account_id is required — you belong to several accounts. Call list_accounts."}
    end
  end

  defp pick_account(user, id) when is_binary(id) do
    case Integer.parse(String.trim(id)) do
      {int, ""} -> pick_account(user, int)
      _ -> {:error, "account_id must be an integer."}
    end
  end

  defp pick_account(user, id) when is_integer(id) do
    if AccountAccess.member?(user.id, id),
      do: {:ok, id},
      else: {:error, "You are not a member of account #{id}. Call list_accounts."}
  end

  defp pick_account(_user, _id), do: {:error, "account_id must be an integer."}

  defp check_write(%{write: true}, %{scope: scope}) do
    if AccountAccess.can_write?(scope),
      do: :ok,
      else:
        {:error,
         "Your role on this account is read-only: you can check setup but not change it. " <>
           "Ask an owner, admin or account manager."}
  end

  defp check_write(_spec, _ctx), do: :ok

  # Pin the account, so the link connects the account the agent acted on.
  defp connect_path(key, %Scope{account_id: id}) when is_integer(id),
    do: Onboarding.connect_path(key) <> "&" <> URI.encode_query(%{account_id: id})

  defp connect_path(key, _scope), do: Onboarding.connect_path(key)

  defp render_status(scope) do
    Enum.map(Onboarding.status(scope), fn conn ->
      %{
        connection: conn.key,
        name: conn.name,
        state: conn.state,
        products:
          Enum.map(conn.products, fn p ->
            %{
              product: p.key,
              name: p.name,
              status: p.status,
              selected: p.selected,
              connected_as: p.connected_as,
              gives: p.gives
            }
          end)
      }
    end)
  end

  defp object(props, required \\ []),
    do: %{type: "object", properties: props, required: required}

  defp parse(value, allowed) do
    if value in allowed,
      do: Onboarding.parse_key(value) |> then(&if(&1 == :error, do: bad(value), else: &1)),
      else: bad(value)
  end

  defp bad(value), do: {:error, "Unknown value #{inspect(value)}."}

  defp wrap({:ok, _} = ok), do: ok
  defp wrap({:error, reason}), do: {:error, Onboarding.explain_error(reason)}

  defp wrap_ok(:ok), do: :ok
  defp wrap_ok({:error, reason}), do: {:error, Onboarding.explain_error(reason)}
end
