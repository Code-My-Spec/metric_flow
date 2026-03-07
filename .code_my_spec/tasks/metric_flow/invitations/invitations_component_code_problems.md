Code requirements not met:
- Component tests are passing: Test failures found

Problems found in implementation files:
8 errors

test/metric_flow/invitations_test.exs:118: [error] match (=) failed
code:  assert {:ok, %Invitation{}} =
         Invitations.send_invitation(
           scope,
           account.id,
           %{recipient_email: "invitee@example.com", role: :read_only}
         )
left:  {:ok,
        {:%, [line: 124, column: 20],
         [
           MetricFlow.Invitations.Invitation,
           {:%{}, [line: 124, column: 31], []}
         ]}}
right: {:error,
        #Ecto.Changeset<
          action: :insert,
          changes: %{
            role: :read_only,
            expires_at: ~U[2026-03-14 14:58:33Z],
            account_id: 4023,
            invited_by_user_id: 7333,
            token_hash: <<244, 15, 123, 142, 73, 134, 70, 245, 179, 120, 121,
              112, 32, 66, 5, 33, 84, 15, 162, 199, 44, 210, 72, 42, 23, 185,
              97, 233, 129, 164, 211, 190>>
          },
          errors: [email: {"can't be blank", [validation: :required]}],
          data: #MetricFlow.Invitations.Invitation<>,
          valid?: false,
          ...
        >}
stacktrace:       test/metric_flow/invitations_test.exs:124: (test)
 (exunit)
test/metric_flow/invitations_test.exs:132: [error] match (=) failed
code:  assert {:ok, %Invitation{}} =
         Invitations.send_invitation(
           scope,
           account.id,
           %{recipient_email: "invitee@example.com", role: :read_only}
         )
left:  {:ok,
        {:%, [line: 138, column: 20],
         [
           MetricFlow.Invitations.Invitation,
           {:%{}, [line: 138, column: 31], []}
         ]}}
right: {:error,
        #Ecto.Changeset<
          action: :insert,
          changes: %{
            role: :read_only,
            expires_at: ~U[2026-03-14 14:58:33Z],
            account_id: 3998,
            invited_by_user_id: 7290,
            token_hash: <<155, 68, 234, 103, 92, 218, 106, 42, 38, 95, 65, 210,
              134, 56, 213, 32, 70, 63, 241, 135, 23, 26, 221, 246, 156, 18, 98,
              22, 141, 114, 227, 145>>
          },
          errors: [email: {"can't be blank", [validation: :required]}],
          data: #MetricFlow.Invitations.Invitation<>,
          valid?: false,
          ...
        >}
stacktrace:       test/metric_flow/invitations_test.exs:138: (test)
 (exunit)
test/metric_flow/invitations_test.exs:146: [error] ** (MatchError) no match of right hand side value:

    {:error,
     #Ecto.Changeset<
       action: :insert,
       changes: %{
         role: :read_only,
         expires_at: ~U[2026-03-14 14:58:33Z],
         account_id: 4020,
         invited_by_user_id: 7329,
         token_hash: <<70, 181, 32, 135, 165, 96, 90, 99, 146, 90, 87, 82, 184, 223,
           12, 149, 191, 162, 95, 152, 16, 14, 157, 78, 157, 181, 200, 243, 182,
           221, 205, 222>>
       },
       errors: [email: {"can't be blank", [validation: :required]}],
       data: #MetricFlow.Invitations.Invitation<>,
       valid?: false,
       ...
     >}
code: {:ok, invitation} =
stacktrace:       test/metric_flow/invitations_test.exs:152: (test)
 (exunit)
test/metric_flow/invitations_test.exs:162: [error] ** (MatchError) no match of right hand side value:

    {:error,
     #Ecto.Changeset<
       action: :insert,
       changes: %{
         role: :account_manager,
         expires_at: ~U[2026-03-14 14:58:33Z],
         account_id: 4001,
         invited_by_user_id: 7295,
         token_hash: <<32, 84, 4, 71, 41, 16, 19, 93, 129, 29, 140, 245, 228, 71,
           111, 77, 115, 240, 58, 130, 23, 215, 218, 24, 213, 148, 68, 35, 179, 116,
           64, 129>>
       },
       errors: [email: {"can't be blank", [validation: :required]}],
       data: #MetricFlow.Invitations.Invitation<>,
       valid?: false,
       ...
     >}
code: {:ok, invitation} =
stacktrace:       test/metric_flow/invitations_test.exs:168: (test)
 (exunit)
test/metric_flow/invitations_test.exs:178: [error] ** (MatchError) no match of right hand side value:

    {:error,
     #Ecto.Changeset<
       action: :insert,
       changes: %{
         role: :read_only,
         expires_at: ~U[2026-03-14 14:58:33Z],
         account_id: 4008,
         invited_by_user_id: 7307,
         token_hash: <<223, 11, 164, 33, 42, 51, 249, 164, 85, 43, 16, 159, 85, 223,
           157, 95, 127, 54, 47, 147, 76, 22, 211, 34, 62, 33, 129, 87, 125, 227,
           212, 228>>
       },
       errors: [email: {"can't be blank", [validation: :required]}],
       data: #MetricFlow.Invitations.Invitation<>,
       valid?: false,
       ...
     >}
code: {:ok, invitation} =
stacktrace:       test/metric_flow/invitations_test.exs:184: (test)
 (exunit)
test/metric_flow/invitations_test.exs:194: [error] ** (MatchError) no match of right hand side value:

    {:error,
     #Ecto.Changeset<
       action: :insert,
       changes: %{
         role: :read_only,
         expires_at: ~U[2026-03-14 14:58:33Z],
         account_id: 4003,
         invited_by_user_id: 7297,
         token_hash: <<213, 114, 22, 243, 176, 17, 94, 233, 246, 63, 162, 254, 231,
           143, 45, 241, 202, 200, 65, 53, 132, 103, 200, 101, 143, 45, 245, 243,
           161, 45, 58, 17>>
       },
       errors: [email: {"can't be blank", [validation: :required]}],
       data: #MetricFlow.Invitations.Invitation<>,
       valid?: false,
       ...
     >}
code: {:ok, invitation} =
stacktrace:       test/metric_flow/invitations_test.exs:201: (test)
 (exunit)
test/metric_flow/invitations_test.exs:212: [error] ** (MatchError) no match of right hand side value:

    {:error,
     #Ecto.Changeset<
       action: :insert,
       changes: %{
         role: :read_only,
         expires_at: ~U[2026-03-14 14:58:33Z],
         account_id: 4030,
         invited_by_user_id: 7344,
         token_hash: <<170, 41, 239, 215, 79, 25, 157, 37, 78, 188, 192, 85, 42, 1,
           95, 200, 15, 229, 83, 82, 244, 156, 131, 44, 64, 118, 228, 165, 177, 152,
           221, 75>>
       },
       errors: [email: {"can't be blank", [validation: :required]}],
       data: #MetricFlow.Invitations.Invitation<>,
       valid?: false,
       ...
     >}
code: {:ok, invitation} =
stacktrace:       test/metric_flow/invitations_test.exs:218: (test)
 (exunit)
test/metric_flow/invitations_test.exs:228: [error] Assertion failed, no matching message after 0ms
The process mailbox is empty.
code: assert_received {:email, email}
left: {:email, {:email, [line: 110, column: 30], nil}}
stacktrace:       (swoosh 1.21.0) lib/swoosh/test_assertions.ex:110: Swoosh.TestAssertions.assert_email_sent/1
       test/metric_flow/invitations_test.exs:237: (test)
 (exunit)

Please fix these issues and try again.