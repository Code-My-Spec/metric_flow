defmodule MetricFlow.AiAgencyChatToolsTest do
  use MetricFlowTest.DataCase, async: true

  import MetricFlowTest.UsersFixtures

  alias MetricFlow.Accounts
  alias MetricFlow.Ai
  alias MetricFlow.Users.Scope

  test "agency-chat-tools: criterion 1 - an agency account's chat serves the :mcp tools and the agency prompt" do
    user = user_fixture()
    scope = Scope.for_user(user)

    {:ok, agency} =
      Accounts.create_team_account(
        scope,
        %{name: "Joel Agency", slug: "joel-agency-#{System.unique_integer([:positive])}"},
        :agency
      )

    scope = Scope.put_account_id(scope, agency.id)
    {:ok, session} = Ai.create_chat_session(scope, %{context_type: :general})

    test_pid = self()

    stream_fn = fn system_prompt, _messages, _on_chunk, opts ->
      send(test_pid, {:llm_call, system_prompt, opts[:tools]})
      {:ok, "ok"}
    end

    {:ok, _pid} = Ai.send_chat_message(scope, session.id, "hi", stream_chat_fn: stream_fn)
    assert_receive {:llm_call, system_prompt, tools}, 5000

    names = Enum.map(tools, & &1.name)
    assert "list_accounts" in names
    assert "invite_client" in names

    setup_status = Enum.find(tools, &(&1.name == "get_setup_status"))
    assert Map.has_key?(setup_status.input_schema.properties, :account_id)

    assert system_prompt =~ "agency"
    assert system_prompt =~ "invite_client"
  end

  test "agency-chat-tools: criterion 2 - get_connect_link for a client returns a link pinned to that client's account_id" do
    user = user_fixture()
    scope = Scope.for_user(user)

    {:ok, agency} =
      Accounts.create_team_account(
        scope,
        %{name: "Joel Agency", slug: "joel-agency-#{System.unique_integer([:positive])}"},
        :agency
      )

    {:ok, acme} =
      Accounts.create_team_account(
        scope,
        %{name: "Acme", slug: "acme-#{System.unique_integer([:positive])}"},
        :client
      )

    scope = Scope.put_account_id(scope, agency.id)

    tool =
      Enum.find(MetricFlow.Onboarding.Tools.alloy_tools(scope), &(&1.name == "get_connect_link"))

    assert tool

    assert {:ok, json} = tool.execute.(%{"connection" => "google", "account_id" => acme.id}, %{})
    url = Jason.decode!(json)["url"]

    assert URI.decode_query(URI.parse(url).query)["account_id"] == to_string(acme.id)
  end

  test "agency-chat-tools: criterion 3 - a client account's chat keeps the :chat tools and the setup prompt" do
    user = user_fixture()
    scope = Scope.for_user(user)

    {:ok, acme} =
      Accounts.create_team_account(
        scope,
        %{name: "Acme", slug: "acme-#{System.unique_integer([:positive])}"},
        :client
      )

    scope = Scope.put_account_id(scope, acme.id)
    {:ok, session} = Ai.create_chat_session(scope, %{context_type: :general})

    test_pid = self()

    stream_fn = fn system_prompt, _messages, _on_chunk, opts ->
      send(test_pid, {:llm_call, system_prompt, opts[:tools]})
      {:ok, "ok"}
    end

    {:ok, _pid} = Ai.send_chat_message(scope, session.id, "hi", stream_chat_fn: stream_fn)
    assert_receive {:llm_call, system_prompt, tools}, 5000

    assert Enum.map(tools, & &1.name) ==
             ~w(get_setup_status get_connect_link list_sync_options save_sync_selection sync_now disconnect_product)

    refute Enum.any?(tools, &Map.has_key?(&1.input_schema.properties, :account_id))
    assert system_prompt =~ "set up the user's data sources"
    refute system_prompt =~ "list_accounts"
    refute system_prompt =~ "invite_client"
  end
end
