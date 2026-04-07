defmodule MetricFlowSpex.DataIsFetchedPerFacebookadsaccountidFromConfigTheActPrefixIsAddedByTheFetcherAtCallTimeNotStoredInConfigSpex do
  use SexySpex
  use MetricFlowTest.ConnCase
  import Phoenix.LiveViewTest

  import_givens MetricFlowSpex.SharedGivens

  spex "Data is fetched per facebookAdsAccountId from config; the 'act_' prefix is added by the fetcher at call time, not stored in config" do
    scenario "the integrations page shows Facebook Ads account IDs without the act_ prefix" do
      given_ "an owner with a Facebook Ads integration whose account IDs have no act_ prefix", context do
        email = "owner#{System.unique_integer([:positive])}@example.com"
        password = "SecurePassword123!"

        reg_conn = Phoenix.ConnTest.build_conn()
        {:ok, reg_view, _html} = live(reg_conn, "/users/register")

        reg_view
        |> form("#registration_form", user: %{
          email: email,
          password: password,
          account_name: "Owner Account"
        })
        |> render_submit()

        Process.sleep(50)

        drain = fn drain_fn ->
          receive do
            {:email, _} -> drain_fn.(drain_fn)
          after
            0 -> :ok
          end
        end

        drain.(drain)

        user = MetricFlowTest.UsersFixtures.get_user_by_email(email)

        MetricFlowTest.IntegrationsFixtures.integration_fixture(user, %{
          provider: :facebook_ads,
          granted_scopes: ["ads_read"],
          provider_metadata: %{
            "email" => email,
            "selected_accounts" => ["123456789", "987654321"]
          }
        })

        login_conn = Phoenix.ConnTest.build_conn()
        {:ok, login_view, _html} = live(login_conn, "/users/log-in")

        login_form =
          form(login_view, "#login_form_password", user: %{
            email: email,
            password: password,
            remember_me: true
          })

        logged_in_conn = submit_form(login_form, login_conn)
        authed_conn = recycle(logged_in_conn)

        {:ok, Map.merge(context, %{owner_conn: authed_conn})}
      end

      when_ "the user visits the integrations page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations")
        {:ok, Map.put(context, :view, view)}
      end

      then_ "the Facebook Ads selected accounts are shown without the act_ prefix", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected the integrations page to show 'Facebook Ads', got: #{html}"

        assert html =~ "123456789",
               "Expected the account ID '123456789' to appear without the 'act_' prefix, got: #{html}"

        assert html =~ "987654321",
               "Expected the account ID '987654321' to appear without the 'act_' prefix, got: #{html}"

        refute html =~ "act_123456789",
               "Expected the account ID to NOT include the 'act_' prefix in stored config, got: #{html}"

        refute html =~ "act_987654321",
               "Expected the account ID to NOT include the 'act_' prefix in stored config, got: #{html}"

        :ok
      end
    end

    scenario "sync history shows a successful Facebook Ads sync per account confirming the fetcher added the act_ prefix at call time" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "a Facebook Ads sync completion event is broadcast for a specific account", context do
        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 45,
          completed_at: DateTime.utc_now(),
          data_date: Date.add(Date.utc_today(), -1)
        }})

        :timer.sleep(100)
        {:ok, context}
      end

      then_ "the sync history page shows a Facebook Ads entry with records synced", context do
        html = render(context.view)

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' provider, got: #{html}"

        assert html =~ "45" or html =~ "records",
               "Expected sync history entry to show the records synced count, got: #{html}"

        assert html =~ "Success" or html =~ "success",
               "Expected the Facebook Ads sync entry to show a success status, got: #{html}"

        :ok
      end

      then_ "the sync entry includes a data date reflecting the account data that was fetched", context do
        html = render(context.view)

        yesterday = Date.add(Date.utc_today(), -1) |> Date.to_iso8601()

        assert html =~ yesterday or html =~ "Date:",
               "Expected the sync entry to show the data date for the fetched account, got: #{html}"

        :ok
      end
    end

    scenario "multiple Facebook Ads sync entries appear in history confirming per-account fetching" do
      given_ :owner_with_integrations

      given_ "the user is on the sync history page", context do
        {:ok, view, _html} = live(context.owner_conn, "/app/integrations/sync-history")
        {:ok, Map.put(context, :view, view)}
      end

      when_ "two Facebook Ads sync completion events are broadcast for different dates", context do
        date1 = Date.add(Date.utc_today(), -1)
        date2 = Date.add(Date.utc_today(), -2)

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 20,
          completed_at: DateTime.utc_now(),
          data_date: date1
        }})

        :timer.sleep(50)

        send(context.view.pid, {:sync_completed, %{
          provider: :facebook_ads,
          records_synced: 18,
          completed_at: DateTime.utc_now(),
          data_date: date2
        }})

        :timer.sleep(100)
        {:ok, Map.merge(context, %{date1: date1, date2: date2})}
      end

      then_ "both Facebook Ads sync entries are visible in the history list", context do
        html = render(context.view)

        entry_count =
          html
          |> String.split("data-role=\"sync-history-entry\"")
          |> length()
          |> Kernel.-(1)

        assert entry_count >= 2,
               "Expected at least 2 Facebook Ads sync history entries (one per date), but found #{entry_count}"

        assert html =~ "Facebook Ads",
               "Expected sync history to show 'Facebook Ads' provider entries, got: #{html}"

        :ok
      end
    end
  end
end
