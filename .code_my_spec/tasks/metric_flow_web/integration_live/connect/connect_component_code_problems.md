Code requirements not met:
- Component tests are passing: Test failures found

Problems found in implementation files:
11 errors

test/metric_flow_web/live/integration_live/connect_test.exs:266: [error] Expected truthy, got false
code: assert String.starts_with?(redirect_url, "https://")
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:278: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test handle_event connect redirects to the OAuth provider authorization URL on success"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:270: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:282: [error] Assertion with == failed
code:  assert redirect_url == StubStrategy.auth_url()
left:  "/integrations/oauth/authorize/stub"
right: "https://stub.example.com/oauth/authorize?response_type=code&state=liveview-csrf-state-token"
stacktrace:       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:288: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:300: [error] ** (FunctionClauseError) no function clause matching in Kernel.=~/2code: capture_log(fn ->
stacktrace:       (elixir 1.19.4) Kernel.=~({:error, {:redirect, %{status: 302, to: "/integrations/oauth/authorize/unsupported_platform"}}}, "This platform is not yet supported")
       test/metric_flow_web/live/integration_live/connect_test.exs:312: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test handle_event connect shows an error flash for an unsupported provider"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:304: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:316: [error] ** (FunctionClauseError) no function clause matching in Kernel.=~/2code: capture_log(fn ->
stacktrace:       (elixir 1.19.4) Kernel.=~({:error, {:redirect, %{status: 302, to: "/integrations/oauth/authorize/stub_authorize_error"}}}, "Could not initiate connection. Please try again.")
       test/metric_flow_web/live/integration_live/connect_test.exs:330: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test handle_event connect shows a generic error flash when authorize_url returns an unexpected error"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:322: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:340: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{to: "/integrations", flash: %{"info" => "Successfully connected!"}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:347: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) assigns status :connected when code param is present and callback succeeds"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:346: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:358: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{to: "/integrations", flash: %{"info" => "Successfully connected!"}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:365: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) assigns status :connected and renders the integration confirmation view on success"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:364: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:377: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{to: "/integrations/connect/stub", flash: %{"error" => "Access was denied"}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:384: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) assigns status :error when the error param is present (e.g. access_denied)"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:383: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:392: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{to: "/integrations/connect/stub", flash: %{"error" => "Access was denied"}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:399: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) shows the Access was denied error message when the error param is access_denied"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:398: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:407: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{
        to: "/integrations/connect/stub_callback_error",
        flash: %{"error" => "Could not complete the connection. Please try again."}
      }}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:414: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) assigns status :error and shows a generic error message when handle_callback fails"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:413: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:425: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{to: "/integrations/connect/stub", flash: %{"error" => "Access was denied"}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:430: anonymous fn/1 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) renders Try again and Back to integrations links on the error view"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:429: (test)
 (exunit)
test/metric_flow_web/live/integration_live/connect_test.exs:438: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:redirect,
      %{to: "/integrations", flash: %{"info" => "Successfully connected!"}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/integration_live/connect_test.exs:446: anonymous fn/3 in MetricFlowWeb.IntegrationLive.ConnectTest."test mount/3 (callback route) persists the integration record in the database on a successful callback"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/integration_live/connect_test.exs:445: (test)
 (exunit)

Please fix these issues and try again.