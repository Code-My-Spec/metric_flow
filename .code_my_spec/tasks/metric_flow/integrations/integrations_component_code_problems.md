Code requirements not met:
- Component tests are passing: Test failures found

Problems found in implementation files:
1 error

test/metric_flow/integrations_test.exs:349: [error] ** (ArgumentError) could not fetch application environment :google_client_secret for application :metric_flow because configuration at :google_client_secret was not setcode: capture_log(fn ->
stacktrace:       (elixir 1.19.4) lib/application.ex:775: Application.fetch_env!/2
       (metric_flow 0.1.0) lib/metric_flow/integrations/providers/google.ex:34: MetricFlow.Integrations.Providers.Google.config/0
       (metric_flow 0.1.0) lib/metric_flow/integrations.ex:77: MetricFlow.Integrations.authorize_url/2
       test/metric_flow/integrations_test.exs:365: anonymous fn/1 in MetricFlow.IntegrationsTest."test authorize_url/1 with real Google provider generates a valid Google OAuth authorization URL through Assent"/1
       (req_cassette 0.5.2) lib/req_cassette.ex:865: ReqCassette.do_with_cassette/3
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow/integrations_test.exs:353: (test)
 (exunit)

Please fix these issues and try again.