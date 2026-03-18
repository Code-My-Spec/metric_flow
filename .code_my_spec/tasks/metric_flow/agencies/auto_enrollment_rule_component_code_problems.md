Code requirements not met:
- Component tests are passing: Test failures found

Problems found in implementation files:
1 error

test/metric_flow/agencies/auto_enrollment_rule_test.exs:222: [error] ** (MatchError) no match of right hand side value:

    {:error, :simulated_failure}
code: account = account_fixture()
stacktrace:       (metric_flow 0.1.0) test/support/fixtures/users_fixtures.ex:71: MetricFlowTest.UsersFixtures.extract_user_token/1
       (metric_flow 0.1.0) test/support/fixtures/users_fixtures.ex:36: MetricFlowTest.UsersFixtures.user_fixture/1
       (metric_flow 0.1.0) test/support/fixtures/agencies_fixtures.ex:35: MetricFlowTest.AgenciesFixtures.account_fixture/1
       test/metric_flow/agencies/auto_enrollment_rule_test.exs:223: (test)
 (exunit)

Please fix these issues and try again.