Code requirements not met:
- Component tests are passing: Test failures found

Problems found in implementation files:
4 errors

test/metric_flow_web/live/ai_live/chat_test.exs:165: [error] Assertion with > failed, both sides are exactly equal
code: assert lv |> render() |> String.split("[data-role=\"example-prompt\"]") |> length() > 1
left: 1
stacktrace:       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/ai_live/chat_test.exs:168: (test)
 (exunit)
test/metric_flow_web/live/ai_live/chat_test.exs:407: [error] ** (MatchError) no match of right hand side value:

    {:error,
     {:live_redirect,
      %{to: "/chat", flash: %{"error" => "Chat session not found."}}}}
code: capture_log(fn ->
stacktrace:       test/metric_flow_web/live/ai_live/chat_test.exs:413: anonymous fn/2 in MetricFlowWeb.AiLive.ChatTest."test handle_params/3 :show action puts an error flash and redirects to /chat when session id is not found"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/ai_live/chat_test.exs:410: (test)
 (exunit)
test/metric_flow_web/live/ai_live/chat_test.exs:489: [error] Assertion with =~ failed
code:  assert render(lv) =~ "AI Chat"
left:  "<div id=\"phx-GJp7ZFnizC5dvxMB\" data-phx-main=\"\" data-phx-session=\"SFMyNTY.g2gDaAJhBnQAAAAIdwJpZG0AAAAUcGh4LUdKcDdaRm5pekM1ZHZ4TUJ3B3Nlc3Npb250AAAAAHcKcGFyZW50X3BpZHcDbmlsdwZyb3V0ZXJ3G0VsaXhpci5NZXRyaWNGbG93V2ViLlJvdXRlcncEdmlld3cgRWxpeGlyLk1ldHJpY0Zsb3dXZWIuQWlMaXZlLkNoYXR3CHJvb3RfcGlkdwNuaWx3CXJvb3Rfdmlld3cgRWxpeGlyLk1ldHJpY0Zsb3dXZWIuQWlMaXZlLkNoYXR3EWxpdmVfc2Vzc2lvbl9uYW1ldxpyZXF1aXJlX2F1dGhlbnRpY2F0ZWRfdXNlcm4GAFI0_sacAWIAAVGA.7I5Qw9auiutO_B1gtXtBsM0iPdNWsB4a5BHrS6blU2w\" data-phx-static=\"SFMyNTY.g2gDaAJhBnQAAAADdwJpZG0AAAAUcGh4LUdKcDdaRm5pekM1ZHZ4TUJ3BWZsYXNodAAAAAB3CmFzc2lnbl9uZXdsAAAAAXcNY3VycmVudF9zY29wZWpuBgBSNP7GnAFiAAFRgA.gazeX4HOz5X4z2mwi6GVNGn2rRqxzyvColZFHyYaOX4\"><div class=\"navbar mf-topnav px-4 sm:px-6 lg:px-8\"><div class=\"navbar-start\"><div class=\"dropdown\"><div tabindex=\"0\" role=\"button\" class=\"btn btn-ghost lg:hidden\"><svg xmlns=\"http://www.w3.org/2000/svg\" class=\"h-5 w-5\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M4 6h16M4 12h8m-8 6h16\"></path></svg></div><ul tabindex=\"-1\" class=\"menu menu-sm dropdown-content bg-base-200 rounded-box z-10 mt-3 w-52 p-2 shadow\"><li><a href=\"/integrations\">Integrations</a></li><li><a href=\"/correlations\">Correlations</a></li><li><a href=\"/insights\">Insights</a></li><li><a href=\"/chat\">Chat</a></li><li><a href=\"/accounts\">Accounts</a></li></ul></div><a href=\"/\" class=\"btn btn-ghost text-lg font-bold tracking-tight\"><span class=\"text-primary\">Metric</span><span class=\"text-accent\">Flow</span></a></div><div class=\"navbar-center hidden lg:flex\"><ul class=\"menu menu-horizontal px-1\"><li><a href=\"/integrations\">Integrations</a></li><li><a href=\"/correlations\">Correlations</a></li><li><a href=\"/insights\">Insights</a></li><li><a href=\"/chat\">Chat</a></li><li><a href=\"/accounts\">Accounts</a></li></ul></div><div class=\"navbar-end gap-2\"><div class=\"dropdown dropdown-end\"><div tabindex=\"0\" role=\"button\" class=\"btn btn-ghost btn-circle avatar placeholder\"><div class=\"bg-primary text-primary-content w-8 rounded-full\"><span class=\"text-xs\">\n              U\n            </span></div></div><ul tabindex=\"-1\" class=\"menu menu-sm dropdown-content bg-base-200 rounded-box z-10 mt-3 w-52 p-2 shadow\"><li class=\"menu-title text-xs\">user-576460752303418719@example.com</li><li><a href=\"/users/settings\">Settings</a></li><li><a href=\"/users/log-out\" method=\"delete\">Log out</a></li></ul></div></div></div><main class=\"mf-content px-4 py-10 sm:px-6 lg:px-8\"><div class=\"mx-auto max-w-[1400px] space-y-4\"><div class=\"flex h-[calc(100vh-4rem)] mf-content overflow-hidden\"><div data-role=\"session-sidebar\" class=\"w-64 flex-shrink-0 flex flex-col border-r border-base-content/10 overflow-hidden fixed inset-0 z-20 bg-base-100 flex flex-col\"><div class=\"flex items-center justify-between px-4 py-3 border-b border-base-content/10 flex-shrink-0\"><h2 class=\"text-sm font-semibold text-base-content/60 uppercase tracking-wide\">\n          Chats\n        </h2><button phx-click=\"new_chat\" data-role=\"new-chat-btn\" class=\"btn btn-primary btn-xs\">\n          + New Chat\n        </button></div><div data-role=\"session-list\" class=\"flex-1 overflow-y-auto py-2\"><p data-role=\"no-sessions-state\" class=\"text-xs text-base-content/40 px-4 py-3\">\n          No chats yet\n        </p></div></div><div data-role=\"conversation-area\" class=\"flex-1 flex flex-col overflow-hidden\"><div class=\"flex items-center gap-3 px-4 py-3 border-b border-base-content/10 flex-shrink-0\"><button phx-click=\"toggle_sidebar\" data-role=\"sidebar-toggle\" class=\"btn btn-ghost btn-sm sm:hidden\" aria-label=\"Toggle sidebar\"><svg xmlns=\"http://www.w3.org/2000/svg\" class=\"h-5 w-5\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M4 6h16M4 12h16M4 18h16\"></path></svg></button><h1 data-role=\"new-chat-header\" class=\"text-base font-semibold\">\n          New Chat\n        </h1></div><div data-role=\"chat-empty-state\" class=\"flex-1 flex flex-col items-center justify-center px-8 text-center\"><h2 class=\"text-xl font-semibold\">A" <> ...
right: "AI Chat"
stacktrace:       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/ai_live/chat_test.exs:492: (test)
 (exunit)
test/metric_flow_web/live/ai_live/chat_test.exs:819: [error] Expected false or nil, got true
code: refute has_element?(lv, "[data-role='send-btn'][disabled]")
stacktrace:       test/metric_flow_web/live/ai_live/chat_test.exs:829: anonymous fn/3 in MetricFlowWeb.AiLive.ChatTest."test handle_info {:chat_complete, meta} re-enables the send button after streaming completes"/1
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:121: ExUnit.CaptureLog.with_log/2
       (ex_unit 1.19.4) lib/ex_unit/capture_log.ex:83: ExUnit.CaptureLog.capture_log/2
       test/metric_flow_web/live/ai_live/chat_test.exs:823: (test)
 (exunit)

Please fix these issues and try again.