Code requirements not met:
- Component tests are passing: Test failures found

Problems found in implementation files:
1 error

test/metric_flow/invitations/invitation_test.exs:265: [error] Assertion with == failed
code:  assert get_change(changeset, :status) == :pending
left:  nil
right: :pending
stacktrace:       test/metric_flow/invitations/invitation_test.exs:273: (test)
 (exunit)

Please fix these issues and try again.