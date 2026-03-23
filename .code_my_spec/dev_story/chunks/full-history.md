# Git Log: MetricFlow Full History

Commits: 40

## 88170e8 - Remove white-label from account settings, update auto-enrollment copy

Date: 2026-03-20 00:14:29 -0400
Author: John Davenport


 lib/metric_flow_web/live/account_live/settings.ex | 17 ++++++-----------
 lib/metric_flow_web/live/agency_live/settings.ex  |  2 +-
 2 files changed, 7 insertions(+), 12 deletions(-)
## 0973267 - Add agency-to-account linking UI and white-label originator auto-apply

Date: 2026-03-20 00:04:57 -0400
Author: John Davenport


 lib/metric_flow/accounts.ex                       |   1 +
 lib/metric_flow/accounts/account_repository.ex    |  13 +++
 lib/metric_flow/agencies.ex                       |  58 +++++++++++
 lib/metric_flow/agencies/agencies_repository.ex   |  48 +++++++++
 lib/metric_flow_web/hooks/white_label_hook.ex     |  32 +++++-
 lib/metric_flow_web/live/account_live/settings.ex | 121 +++++++++++++++++++++-
 lib/metric_flow_web/live/agency_live/settings.ex  | 109 +++++++++++++++++++
 7 files changed, 376 insertions(+), 6 deletions(-)
## f4661c2 - Fix prod deployment, rewrite QuickBooks provider for daily credit/debit sync

Date: 2026-03-19 23:31:38 -0400
Author: John Davenport


 .code_my_spec/devops/hetzner-deploy.md             |   40 +-
 config/runtime.exs                                 |    5 +-
 docker-compose.yml                                 |   12 +-
 .../data_sync/data_providers/google_ads.ex         |    3 +-
 .../data_sync/data_providers/quick_books.ex        |  383 +-
 .../integrations/google_ads_accounts.ex            |   56 +-
 .../integrations/quickbooks_accounts.ex            |    6 +-
 .../live/integration_live/connect.ex               |    2 +-
 lib/metric_flow_web/live/integration_live/index.ex |    2 +-
 .../data_sync/quickbooks_fetch_metrics.json        | 7708 +++++++++++++++++++-
 .../data_sync/quickbooks_unauthorized.json         |   74 +-
 .../data_sync/data_providers/quick_books_test.exs  | 1505 ++--
 test/support/fixtures/cassette_fixtures.ex         |   10 +-
 13 files changed, 8058 insertions(+), 1748 deletions(-)
## 5dbb1c4 - Rename env files to .env.uat/.env.prod, remove secrets from git tracking

Date: 2026-03-19 17:18:38 -0400
Author: John Davenport


 .code_my_spec/devops/README.md         | 10 +++++-----
 .code_my_spec/devops/hetzner-deploy.md | 36 +++++++++++++++++-----------------
 .code_my_spec/devops/services.md       | 22 ++++++++++-----------
 docker-compose.prod.yml                |  2 +-
 docker-compose.yml                     |  2 +-
 scripts/deploy                         |  6 ++++--
 scripts/deploy-uat                     |  6 +++++-
 uat.env                                | 30 ----------------------------
 8 files changed, 45 insertions(+), 69 deletions(-)
## d3a6da4 - Fix QA issues: invitation token invalidation, nil account guards, dashboard AI buttons

Date: 2026-03-19 16:18:20 -0400
Author: John Davenport


 .code_my_spec/credo_checks/framework/checks.exs    |      6 +
 .../framework/no_direct_send_in_spex.ex            |     54 +
 .code_my_spec/internal/agent_test_events.json      | 245914 +++++++++++++-----
 ...28-accepted_invitation_link_is_not_invalidat.md |     19 +-
 ...28-flash_message_lost_when_revisiting_an_acc.md |     25 +
 ...28-invitation_email_does_not_include_the_rol.md |     21 +
 ...28-validation_errors_displayed_on_fresh_page.md |     25 +
 ...42-bdd_spec_brief_incorrectly_states_dashboa.md |     21 +
 ...46-no_navigation_entry_point_to_goal_metrics.md |     25 +
 ...47-correlation_results_table_shows_results_f.md |     25 +
 ...47-correlations_page_crashes_for_users_with_.md |     34 +
 ...47-data_points_shows_0_data_points_in_correl.md |     21 +
 ...47-data_window_disappears_after_new_run_now_.md |     35 +
 ...47-insufficient_data_warning_badge_not_shown.md |     25 +
 ...47-qa_seed_447_is_not_idempotent_when_real_j.md |     25 +
 ...47-story_447_seed_script_inserts_data_for_wr.md |     39 +
 ...48-duplicate_derived_metric_rows_in_correlat.md |     25 +
 ...49-smart_mode_does_not_implement_top_positiv.md |     25 +
 ...50-dashboard_ai_info_buttons_not_implemented.md |     25 +
 ...50-insights_crashes_with_500_when_user_has_n.md |     25 +
 ...50-qa_empty_example_com_not_created_by_qa_se.md |     25 +
 ...51-no_page_specific_ai_chat_entry_point_on_c.md |     21 +
 ...52-saved_visualizations_have_no_index_page_i.md |     26 +
 ...52-view_in_visualizations_link_points_to_non.md |     27 +
 ...es_use_direct_send_instead_of_ui_driven_sync.md |     88 +
 .code_my_spec/qa/428/result_complete.md            |    165 +
 ...{result.md => result_failed_20260319_075436.md} |      0
 .../qa/428/result_failed_20260319_080815.md        |    225 +
 .../qa/428/result_failed_20260319_130548.md        |    191 +
 .../screenshots/01-invitations-page-initial.png    |    Bin 32924 -> 34973 bytes
 .../screenshots/01_invitations_page_initial.png    |    Bin 0 -> 34973 bytes
 .../02-ac1-send-external-invitation.png            |    Bin 0 -> 39875 bytes
 .../02_ac1b_external_invite_success.png            |    Bin 0 -> 36322 bytes
 .../screenshots/02_invitation_sent_external.png    |    Bin 0 -> 38933 bytes
 .../03-ac1-send-existing-user-invitation.png       |    Bin 0 -> 38373 bytes
 .../03_ac1c_existing_user_invite_success.png       |    Bin 0 -> 35770 bytes
 .../03_invitation_sent_existing_user.png           |    Bin 0 -> 38373 bytes
 .../qa/428/screenshots/04-dev-mailbox.png          |    Bin 0 -> 57054 bytes
 .../qa/428/screenshots/04_ac2_mailbox.png          |    Bin 0 -> 48068 bytes
 .../qa/428/screenshots/04_dev_mailbox.png          |    Bin 0 -> 54220 bytes
 .../qa/428/screenshots/05-mailbox-email-detail.png |    Bin 0 -> 57054 bytes
 .../qa/428/screenshots/05_ac2_email_content.png    |    Bin 0 -> 48068 bytes
 .../428/screenshots/05_invitation_email_detail.png |    Bin 0 -> 54220 bytes
 .../screenshots/06-invitation-acceptance-page.png  |    Bin 0 -> 25571 bytes
 .../screenshots/06_ac4_mailbox_admin_invite.png    |    Bin 0 -> 54624 bytes
 .../screenshots/06_invitation_acceptance_page.png  |    Bin 0 -> 25571 bytes
 .../screenshots/07-mailbox-admin-invite-email.png  |    Bin 0 -> 55239 bytes
 .../qa/428/screenshots/07_ac4_acceptance_page.png  |    Bin 0 -> 24958 bytes
 .../qa/428/screenshots/07_role_select_options.png  |    Bin 0 -> 34973 bytes
 .../screenshots/08-ac4-admin-acceptance-page.png   |    Bin 0 -> 24958 bytes
 .../qa/428/screenshots/08_ac5_role_select.png      |    Bin 0 -> 34973 bytes
 .../qa/428/screenshots/08_all_three_roles_sent.png |    Bin 0 -> 33827 bytes
 .../qa/428/screenshots/09-ac5-role-select.png      |    Bin 0 -> 34973 bytes
 .../428/screenshots/09_ac5_all_roles_pending.png   |    Bin 0 -> 32396 bytes
 .../screenshots/09_acceptance_page_logged_in.png   |    Bin 0 -> 26091 bytes
 .../screenshots/10-ac5-all-three-roles-sent.png    |    Bin 0 -> 33596 bytes
 .../qa/428/screenshots/10_after_acceptance.png     |    Bin 0 -> 31062 bytes
 .../qa/428/screenshots/10_logout_page.png          |    Bin 0 -> 48597 bytes
 .../qa/428/screenshots/11-login-page-member.png    |    Bin 0 -> 25351 bytes
 .../11_ac6_acceptance_page_before_accept.png       |    Bin 0 -> 26091 bytes
 .../428/screenshots/11_reused_invitation_link.png  |    Bin 0 -> 78742 bytes
 .../qa/428/screenshots/12-login-form-state.png     |    Bin 0 -> 25346 bytes
 .../qa/428/screenshots/12_ac6_after_accept.png     |    Bin 0 -> 31062 bytes
 .../12_unauthenticated_acceptance_page.png         |    Bin 0 -> 27117 bytes
 .../screenshots/13-ac6-acceptance-page-member.png  |    Bin 0 -> 26091 bytes
 .../13_ac6_second_visit_accepted_link.png          |    Bin 0 -> 26091 bytes
 .../screenshots/13_pending_invitations_visible.png |    Bin 0 -> 34284 bytes
 .../qa/428/screenshots/14-ac6-after-acceptance.png |    Bin 0 -> 31062 bytes
 .../screenshots/14_ac6_second_accept_no_error.png  |    Bin 0 -> 31062 bytes
 .../qa/428/screenshots/14_cancel_invitation.png    |    Bin 0 -> 38573 bytes
 .../428/screenshots/15-ac6-reuse-accepted-link.png |    Bin 0 -> 77257 bytes
 .../15_ac6_valid_link_unauthenticated.png          |    Bin 0 -> 27117 bytes
 .../qa/428/screenshots/15_multiple_invitations.png |    Bin 0 -> 35427 bytes
 .../428/screenshots/16-ac6-reuse-link-redirect.png |    Bin 0 -> 76754 bytes
 .../screenshots/16_ac7_pending_list_visible.png    |    Bin 0 -> 32579 bytes
 .../qa/428/screenshots/16_final_state.png          |    Bin 0 -> 325959 bytes
 .../17-ac6-unauthenticated-valid-link.png          |    Bin 0 -> 27729 bytes
 .../qa/428/screenshots/17_ac7_cancel_success.png   |    Bin 0 -> 38441 bytes
 .../18-ac7-pending-invitations-list.png            |    Bin 0 -> 39609 bytes
 .../screenshots/18_ac8_multiple_invitations.png    |    Bin 0 -> 37176 bytes
 .../428/screenshots/19-ac7-cancel-invitation.png   |    Bin 0 -> 39635 bytes
 .../screenshots/19_exploratory_invalid_email.png   |    Bin 0 -> 43074 bytes
 .../screenshots/20-ac8-multiple-invitations.png    |    Bin 0 -> 37003 bytes
 .../428/screenshots/20_exploratory_empty_email.png |    Bin 0 -> 36050 bytes
 .../428/screenshots/21-final-invitations-page.png  |    Bin 0 -> 240621 bytes
 .../21_fresh_page_validation_errors.png            |    Bin 0 -> 34973 bytes
 .code_my_spec/qa/429/result_complete.md            |    208 +
 ...{result.md => result_failed_20260319_133958.md} |      0
 .code_my_spec/qa/433/result_complete.md            |     74 +
 ...{result.md => result_failed_20260319_133048.md} |      0
 .../433/screenshots/member_no_transfer_section.png |    Bin 118800 -> 55369 bytes
 .../new_owner_sees_transfer_section.png            |    Bin 0 -> 163298 bytes
 .../screenshots/owner_sees_transfer_section.png    |    Bin 344391 -> 163586 bytes
 .../433/screenshots/transfer_ownership_success.png |    Bin 250359 -> 139808 bytes
 .code_my_spec/qa/445/brief.md                      |    123 +
 .code_my_spec/qa/445/result_complete.md            |    118 +
 .../445/screenshots/01_dashboards_page_initial.png |    Bin 0 -> 79271 bytes
 .../screenshots/02_canned_dashboards_section.png   |    Bin 0 -> 48019 bytes
 .../screenshots/03_user_dashboards_empty_state.png |    Bin 0 -> 79271 bytes
 .../qa/445/screenshots/04_new_dashboard_form.png   |    Bin 0 -> 43892 bytes
 .../screenshots/05_new_dashboard_validation.png    |    Bin 0 -> 43135 bytes
 .../qa/445/screenshots/06_dashboard_saved_view.png |    Bin 0 -> 48399 bytes
 .../07_dashboards_with_user_dashboard.png          |    Bin 0 -> 78921 bytes
 .../screenshots/08_delete_confirmation_prompt.png  |    Bin 0 -> 32957 bytes
 .../09_cancel_delete_card_still_present.png        |    Bin 0 -> 31742 bytes
 .../445/screenshots/10_dashboard_deleted_flash.png |    Bin 0 -> 35488 bytes
 .../445/screenshots/11_canned_dashboard_view.png   |    Bin 0 -> 48996 bytes
 .code_my_spec/qa/446/brief.md                      |    110 +
 .code_my_spec/qa/446/result_complete.md            |    114 +
 .../qa/446/result_failed_20260319_030448.md        |    129 +
 .../qa/446/result_failed_20260319_032658.md        |    129 +
 .../qa/446/screenshots/01_correlations_index.png   |    Bin 0 -> 250801 bytes
 ...01b_correlations_index_with_configure_goals.png |    Bin 0 -> 104205 bytes
 .../01c_goals_page_via_configure_goals_link.png    |    Bin 0 -> 43104 bytes
 .code_my_spec/qa/446/screenshots/02_goals_page.png |    Bin 0 -> 33438 bytes
 .../qa/446/screenshots/02_goals_page_direct.png    |    Bin 0 -> 33438 bytes
 .../screenshots/02b_goals_page_with_metrics.png    |    Bin 0 -> 25653 bytes
 .../446/screenshots/03_goals_page_with_metrics.png |    Bin 0 -> 50184 bytes
 .../screenshots/04_unauth_redirect_login_page.png  |    Bin 0 -> 30916 bytes
 .../screenshots/04_unauthenticated_redirect.png    |    Bin 0 -> 30916 bytes
 .../screenshots/05_after_cancel_correlations.png   |    Bin 0 -> 45335 bytes
 .../05_cancel_navigates_to_correlations.png        |    Bin 0 -> 45933 bytes
 .../446/screenshots/06_goals_page_preselected.png  |    Bin 0 -> 33438 bytes
 .../qa/446/screenshots/06a_goal_selected.png       |    Bin 0 -> 26409 bytes
 .../screenshots/06b_after_save_correlations.png    |    Bin 0 -> 46701 bytes
 .../qa/446/screenshots/07_goal_persisted.png       |    Bin 0 -> 26409 bytes
 .../07_save_goal_flash_and_redirect.png            |    Bin 0 -> 93966 bytes
 .../screenshots/08_goal_persists_after_save.png    |    Bin 0 -> 33587 bytes
 .../446/screenshots/09_exploratory_second_save.png |    Bin 0 -> 178239 bytes
 .../446/screenshots/10_goals_page_final_state.png  |    Bin 0 -> 33438 bytes
 .code_my_spec/qa/447/result_complete.md            |    193 +
 .../qa/447/result_failed_20260319_034110.md        |    249 +
 .../qa/447/result_failed_20260319_035319.md        |    228 +
 .../qa/447/result_failed_20260319_041830.md        |    191 +
 .../qa/447/result_failed_20260319_043430.md        |    205 +
 .../qa/447/screenshots/duplicate-results-bug.png   |    Bin 0 -> 254192 bytes
 .../qa/447/screenshots/filtered-google-ads.png     |    Bin 0 -> 44880 bytes
 .../qa/447/screenshots/no-data-state-attempt.png   |    Bin 0 -> 47495 bytes
 .../qa/447/screenshots/no-data-state-crash.png     |    Bin 0 -> 43655 bytes
 .code_my_spec/qa/447/screenshots/no-data-state.png |    Bin 0 -> 54546 bytes
 .code_my_spec/qa/447/screenshots/page-header.png   |    Bin 0 -> 45205 bytes
 .../qa/447/screenshots/raw-mode-summary.png        |    Bin 0 -> 45205 bytes
 .code_my_spec/qa/447/screenshots/results-table.png |    Bin 0 -> 45205 bytes
 .../qa/447/screenshots/run-correlations-button.png |    Bin 0 -> 45572 bytes
 .../qa/447/screenshots/run-insufficient-data.png   |    Bin 0 -> 57673 bytes
 .../qa/447/screenshots/smart-mode-enabled.png      |    Bin 0 -> 52817 bytes
 .../screenshots/smart-mode-feedback-submitted.png  |    Bin 0 -> 53390 bytes
 .../qa/447/screenshots/smart-mode-optin.png        |    Bin 0 -> 40780 bytes
 .code_my_spec/qa/447/screenshots/sorted-by-lag.png |    Bin 0 -> 45934 bytes
 .../qa/447/screenshots/sorted-by-metric.png        |    Bin 0 -> 45423 bytes
 .../qa/447/screenshots/unified-results.png         |    Bin 0 -> 45205 bytes
 .code_my_spec/qa/448/brief.md                      |    125 +
 .code_my_spec/qa/448/result_complete.md            |     99 +
 .../qa/448/result_failed_20260319_054544.md        |    142 +
 .../qa/448/result_failed_20260319_055914.md        |    115 +
 .../qa/448/result_failed_20260319_060834.md        |    128 +
 .../qa/448/screenshots/01-dashboard-nav.png        |    Bin 0 -> 48282 bytes
 .../01_dashboard_nav_correlations_link.png         |    Bin 0 -> 48282 bytes
 .../qa/448/screenshots/02-correlations-page.png    |    Bin 0 -> 40890 bytes
 .../screenshots/02_correlations_page_loaded.png    |    Bin 0 -> 40991 bytes
 .../screenshots/03-unauthenticated-redirect.png    |    Bin 0 -> 29721 bytes
 .../screenshots/03_unauthenticated_redirect.png    |    Bin 0 -> 29733 bytes
 .../448/screenshots/04-correlations-with-data.png  |    Bin 0 -> 39713 bytes
 .../qa/448/screenshots/04_empty_user_crash.png     |    Bin 0 -> 43655 bytes
 .../qa/448/screenshots/05-mode-toggle.png          |    Bin 0 -> 39713 bytes
 .../448/screenshots/05_mode_toggle_raw_active.png  |    Bin 0 -> 41020 bytes
 .code_my_spec/qa/448/screenshots/06-smart-mode.png |    Bin 0 -> 39728 bytes
 .../qa/448/screenshots/06_smart_mode_panel.png     |    Bin 0 -> 40780 bytes
 .../qa/448/screenshots/07-back-to-raw.png          |    Bin 0 -> 40217 bytes
 .../qa/448/screenshots/07_back_to_raw_mode.png     |    Bin 0 -> 41066 bytes
 .../qa/448/screenshots/08-run-now-started.png      |    Bin 0 -> 42649 bytes
 .../qa/448/screenshots/08_run_now_job_started.png  |    Bin 0 -> 42749 bytes
 .../qa/448/screenshots/09-configure-goals.png      |    Bin 0 -> 42716 bytes
 .../qa/448/screenshots/09_configure_goals_link.png |    Bin 0 -> 40552 bytes
 .../448/screenshots/09b-configure-goals-page.png   |    Bin 0 -> 25653 bytes
 .../448/screenshots/09b_configure_goals_page.png   |    Bin 0 -> 25653 bytes
 .../448/screenshots/10_smart_mode_ai_enabled.png   |    Bin 0 -> 52817 bytes
 .../11_smart_mode_feedback_submitted.png           |    Bin 0 -> 53390 bytes
 .../qa/448/screenshots/exploratory_ai_enabled.png  |    Bin 0 -> 54696 bytes
 .../448/screenshots/exploratory_duplicate_rows.png |    Bin 0 -> 252711 bytes
 .../screenshots/exploratory_feedback_confirmed.png |    Bin 0 -> 53390 bytes
 .../screenshots/exploratory_platform_filter.png    |    Bin 0 -> 46203 bytes
 .../qa/448/screenshots/scenario1_dashboard_nav.png |    Bin 0 -> 48282 bytes
 .../scenario1_nav_correlations_link.png            |    Bin 0 -> 48282 bytes
 .../screenshots/scenario2_correlations_page.png    |    Bin 0 -> 41222 bytes
 .../qa/448/screenshots/scenario3_logout_state.png  |    Bin 0 -> 48597 bytes
 .../scenario3_unauthenticated_redirect.png         |    Bin 0 -> 29721 bytes
 .../scenario4_correlations_with_data.png           |    Bin 0 -> 47901 bytes
 .../qa/448/screenshots/scenario4_no_data_state.png |    Bin 0 -> 54546 bytes
 .../qa/448/screenshots/scenario5_mode_toggle.png   |    Bin 0 -> 41020 bytes
 .../qa/448/screenshots/scenario6_smart_mode.png    |    Bin 0 -> 40780 bytes
 .../qa/448/screenshots/scenario7_back_to_raw.png   |    Bin 0 -> 41066 bytes
 .../screenshots/scenario8_insufficient_data.png    |    Bin 0 -> 63661 bytes
 .../448/screenshots/scenario8_run_now_started.png  |    Bin 0 -> 50190 bytes
 .../448/screenshots/scenario9_configure_goals.png  |    Bin 0 -> 25653 bytes
 .../screenshots/scenario9_configure_goals_link.png |    Bin 0 -> 41066 bytes
 .../qa/448/screenshots/scenario9_goals_page.png    |    Bin 0 -> 25653 bytes
 .code_my_spec/qa/449/brief.md                      |    111 +
 .code_my_spec/qa/449/result_complete.md            |    103 +
 .../qa/449/result_failed_20260319_051107.md        |    105 +
 .../scenario1-correlations-raw-mode.png            |    Bin 0 -> 45457 bytes
 .../449/screenshots/scenario2-smart-mode-panel.png |    Bin 0 -> 40780 bytes
 .../screenshots/scenario3-smart-mode-opt-in.png    |    Bin 0 -> 40780 bytes
 .../scenario4-ai-suggestions-enabled.png           |    Bin 0 -> 52817 bytes
 .../scenario5-missing-top-correlations.png         |    Bin 0 -> 83022 bytes
 .../scenario6-feedback-confirmation.png            |    Bin 0 -> 53390 bytes
 .../449/screenshots/scenario7-back-to-raw-mode.png |    Bin 0 -> 91888 bytes
 .code_my_spec/qa/450/brief.md                      |      8 +-
 .code_my_spec/qa/450/result_complete.md            |    207 +
 ...{result.md => result_failed_20260319_062952.md} |      0
 .../qa/450/result_failed_20260319_064509.md        |    224 +
 .../qa/450/result_failed_20260319_070420.md        |    173 +
 .../qa/450/result_failed_20260319_071643.md        |    187 +
 .../450/screenshots/A1-correlations-raw-mode.png   |    Bin 0 -> 44980 bytes
 .../450/screenshots/A1-correlations-smart-mode.png |    Bin 0 -> 40780 bytes
 .../450/screenshots/A1_correlations_raw_mode.png   |    Bin 191997 -> 44490 bytes
 .../450/screenshots/A1_correlations_smart_mode.png |    Bin 182061 -> 40780 bytes
 .../450/screenshots/A2-ai-suggestions-enabled.png  |    Bin 0 -> 52817 bytes
 .../450/screenshots/A2_ai_suggestions_enabled.png  |    Bin 159915 -> 52817 bytes
 .../qa/450/screenshots/A3-feedback-buttons.png     |    Bin 0 -> 52817 bytes
 .../450/screenshots/A3-feedback-confirmation.png   |    Bin 0 -> 53390 bytes
 .../qa/450/screenshots/A3_feedback_buttons.png     |    Bin 172280 -> 52817 bytes
 .../A3_helpful_feedback_confirmation.png           |    Bin 0 -> 53390 bytes
 .../screenshots/A4-not-helpful-confirmation.png    |    Bin 0 -> 57470 bytes
 .../A4_not_helpful_feedback_confirmation.png       |    Bin 0 -> 53390 bytes
 .../qa/450/screenshots/B1-insights-page-full.png   |    Bin 0 -> 247601 bytes
 .../450/screenshots/B10_budget_decrease_filter.png |    Bin 0 -> 59527 bytes
 .../qa/450/screenshots/B1_insights_full_page.png   |    Bin 0 -> 245465 bytes
 .../450/screenshots/B2-budget-increase-filter.png  |    Bin 0 -> 63645 bytes
 .../450/screenshots/B2_budget_increase_filter.png  |    Bin 157479 -> 63645 bytes
 .../qa/450/screenshots/B4-feedback-section.png     |    Bin 0 -> 63086 bytes
 .../B4_feedback_sections_showing_confirmation.png  |    Bin 0 -> 63086 bytes
 .../screenshots/B5-helpful-feedback-submitted.png  |    Bin 0 -> 80560 bytes
 .../B6-not-helpful-feedback-submitted.png          |    Bin 0 -> 78008 bytes
 .../qa/450/screenshots/B7-personalization-note.png |    Bin 0 -> 78008 bytes
 .../qa/450/screenshots/B7_personalization_note.png |    Bin 103885 -> 63086 bytes
 .../qa/450/screenshots/B8-after-reload.png         |    Bin 0 -> 63056 bytes
 .../B8_feedback_persists_after_reload.png          |    Bin 0 -> 63056 bytes
 .../qa/450/screenshots/B9-empty-state-crash.png    |    Bin 0 -> 43288 bytes
 .../qa/450/screenshots/B9-member-empty-state.png   |    Bin 0 -> 63543 bytes
 .../qa/450/screenshots/B9_empty_state.png          |    Bin 0 -> 41086 bytes
 .../qa/450/screenshots/C1-dashboard-scrolled.png   |    Bin 0 -> 79302 bytes
 .code_my_spec/qa/450/screenshots/C1-dashboard.png  |    Bin 0 -> 48282 bytes
 .code_my_spec/qa/450/screenshots/C1_dashboard.png  |    Bin 273544 -> 48282 bytes
 .../450/screenshots/C1_dashboard_no_ai_buttons.png |    Bin 0 -> 399411 bytes
 .code_my_spec/qa/451/result_complete.md            |    195 +
 ...{result.md => result_failed_20260319_073849.md} |      0
 .../qa/451/screenshots/b10_metrics_response.png    |    Bin 0 -> 38148 bytes
 .../451/screenshots/b11_correlations_response.png  |    Bin 0 -> 38121 bytes
 .../451/screenshots/b12_visualization_response.png |    Bin 0 -> 38121 bytes
 .../qa/451/screenshots/b13_ad_spend_response.png   |    Bin 0 -> 36203 bytes
 .../qa/451/screenshots/b13_streaming_state.png     |    Bin 0 -> 35291 bytes
 .../qa/451/screenshots/b14_restored_chat.png       |    Bin 0 -> 42025 bytes
 .../451/screenshots/b14_session_list_after_nav.png |    Bin 0 -> 29695 bytes
 .../qa/451/screenshots/b15_session_list.png        |    Bin 0 -> 42025 bytes
 .../qa/451/screenshots/b16_share_button.png        |    Bin 0 -> 42025 bytes
 .../qa/451/screenshots/b16_share_clicked.png       |    Bin 0 -> 36864 bytes
 .../qa/451/screenshots/b17_after_logout.png        |    Bin 0 -> 28981 bytes
 .../qa/451/screenshots/b17_login_page.png          |    Bin 0 -> 25351 bytes
 .../qa/451/screenshots/b17_member_chat.png         |    Bin 0 -> 50466 bytes
 .code_my_spec/qa/451/screenshots/b1_dashboard.png  |    Bin 0 -> 48282 bytes
 .../qa/451/screenshots/b2_correlations.png         |    Bin 0 -> 44490 bytes
 .code_my_spec/qa/451/screenshots/b3_insights.png   |    Bin 0 -> 63056 bytes
 .../qa/451/screenshots/b4_chat_initial.png         |    Bin 0 -> 49933 bytes
 .../qa/451/screenshots/b5_chat_empty_state.png     |    Bin 0 -> 49933 bytes
 .../qa/451/screenshots/b6_context_correlation.png  |    Bin 0 -> 49933 bytes
 .../qa/451/screenshots/b7_context_dashboard.png    |    Bin 0 -> 49933 bytes
 .../451/screenshots/b8_message_input_visible.png   |    Bin 0 -> 49933 bytes
 .../qa/451/screenshots/b9_assistant_response.png   |    Bin 0 -> 38123 bytes
 .../qa/451/screenshots/b9_user_message_sent.png    |    Bin 0 -> 37188 bytes
 .code_my_spec/qa/452/result_complete.md            |    127 +
 .../qa/452/result_failed_20260318_212412.md        |    152 +
 .../qa/452/result_failed_20260318_215819.md        |    136 +
 .../qa/452/result_failed_20260318_232111.md        |    154 +
 .../qa/452/result_failed_20260319_005525.md        |    154 +
 .../screenshots/s0_unauthenticated_redirect.png    |    Bin 0 -> 29721 bytes
 .../qa/452/screenshots/s1_initial_state.png        |    Bin 0 -> 33176 bytes
 .../qa/452/screenshots/s2_prompt_filled.png        |    Bin 0 -> 33679 bytes
 .../qa/452/screenshots/s3_after_timeout.png        |    Bin 0 -> 35594 bytes
 .../qa/452/screenshots/s3_chart_generated.png      |    Bin 0 -> 60921 bytes
 .../qa/452/screenshots/s3_generate_error.png       |    Bin 0 -> 35594 bytes
 .../qa/452/screenshots/s3_generating_spinner.png   |    Bin 0 -> 33096 bytes
 .../qa/452/screenshots/s3a_generating_spinner.png  |    Bin 0 -> 33096 bytes
 .../qa/452/screenshots/s4_save_name_input_bug.png  |    Bin 0 -> 23323 bytes
 .../s4_save_name_phx_change_not_firing.png         |    Bin 0 -> 17959 bytes
 .../screenshots/s4_save_section_bug_confirmed.png  |    Bin 0 -> 17959 bytes
 .../screenshots/s4_save_validation_blank_name.png  |    Bin 0 -> 17199 bytes
 .../qa/452/screenshots/s5_save_confirmation.png    |    Bin 0 -> 56406 bytes
 .../qa/452/screenshots/s5_save_name_filled.png     |    Bin 0 -> 55311 bytes
 .../452/screenshots/s6_generate_another_reset.png  |    Bin 0 -> 26261 bytes
 .../qa/452/screenshots/s7_visualizations_page.png  |    Bin 0 -> 47797 bytes
 .../qa/452/screenshots/s8_chart_data_spec.png      |    Bin 0 -> 61149 bytes
 .../452/screenshots/s8_save_confirmation_fixed.png |    Bin 0 -> 71036 bytes
 .../screenshots/s8_visualizations_page_final.png   |    Bin 0 -> 51695 bytes
 .../screenshots/s8_visualizations_page_fixed.png   |    Bin 0 -> 51695 bytes
 .../s8_visualizations_route_missing.png            |    Bin 0 -> 48603 bytes
 .../screenshots/s_visualizations_route_check.png   |    Bin 0 -> 48603 bytes
 .../screenshots/s_visualizations_route_missing.png |    Bin 0 -> 48603 bytes
 .code_my_spec/status/implementation_status.json    |      2 +-
 .code_my_spec/status/metric_flow.md                |      6 +-
 .code_my_spec/status/metric_flow/dashboards.md     |     21 +-
 .code_my_spec/status/metric_flow/data_sync.md      |      8 +-
 .code_my_spec/status/metric_flow/integrations.md   |      2 +-
 .../integrations/strategies/quick_books_o_auth2.md |      2 +-
 .code_my_spec/status/metric_flow_web.md            |      4 +-
 .../status/metric_flow_web/correlation_live.md     |      6 +-
 .../metric_flow_web/correlation_live/goals.md      |      9 +
 .../status/metric_flow_web/visualization_live.md   |     10 +
 .../metric_flow_web/visualization_live/index.md    |      8 +
 .code_my_spec/status/project.md                    |      2 +-
 .code_my_spec/status/stories.md                    |     38 +-
 .code_my_spec/tasks/metric _flow_fix_issues.md     |     16 +-
 .../tasks/metric _flow_fix_issues_problems.md      |      2 +-
 .../facebook_ads_accounts_component_test.md        |     60 +
 ...acebook_ads_accounts_component_test_problems.md |      2 +
 .../integrations/google_accounts_component_test.md |     60 +
 .../google_accounts_component_test_problems.md     |      2 +
 .../google_ads_accounts_component_test.md          |     60 +
 .../google_ads_accounts_component_test_problems.md |      2 +
 .../integrations/google_ads_component_test.md      |     60 +
 .../google_ads_component_test_problems.md          |      2 +
 .../google_analytics_component_test.md             |     60 +
 .../google_analytics_component_test_problems.md    |      2 +
 .../google_search_console_component_test.md        |     60 +
 ...oogle_search_console_component_test_problems.md |      2 +
 .../google_search_console_sites_component_test.md  |     60 +
 ...search_console_sites_component_test_problems.md |      2 +
 .../integrations_context_implementation.md         |     22 +
 ...integrations_context_implementation_problems.md |     11 +
 .../oauth_state_store_component_code.md            |     74 +
 .../oauth_state_store_component_code_problems.md   |      2 +
 .../oauth_state_store_component_test.md            |     62 +
 .../oauth_state_store_component_test_problems.md   |      2 +
 .../quick_books_accounts_component_code.md         |     74 +
 ...quick_books_accounts_component_code_problems.md |      2 +
 .../quick_books_accounts_component_test.md         |     62 +
 ...quick_books_accounts_component_test_problems.md |      2 +
 .../integrations/quick_books_component_test.md     |     60 +
 .../quick_books_component_test_problems.md         |      2 +
 .../quick_books_o_auth2_component_code.md          |     74 +
 .../quick_books_o_auth2_component_code_problems.md |      2 +
 .../quick_books_o_auth2_component_test.md          |     62 +
 .../quick_books_o_auth2_component_test_problems.md |      2 +
 .../correlation_live/goals/goals_component_code.md |    127 +
 .../goals/goals_component_code_problems.md         |      2 +
 .../correlation_live/goals/goals_component_test.md |     62 +
 .../goals/goals_component_test_problems.md         |      2 +
 .../correlation_live/goals/goals_live_view_spec.md |    206 +
 .../goals/goals_live_view_spec_problems.md         |      2 +
 .code_my_spec/tasks/qa/story_432_qa_story.md       |    146 +
 .../445/subagent_prompts/bdd_specs_prompt.md       |    754 +
 .code_my_spec/tasks/stories/445/write_bdd_specs.md |     22 +
 .../446/subagent_prompts/bdd_specs_prompt.md       |    729 +
 .code_my_spec/tasks/stories/446/write_bdd_specs.md |     22 +
 .../448/subagent_prompts/bdd_specs_prompt.md       |    829 +
 .code_my_spec/tasks/stories/448/write_bdd_specs.md |     22 +
 .../449/subagent_prompts/bdd_specs_prompt.md       |    729 +
 .code_my_spec/tasks/stories/449/write_bdd_specs.md |     22 +
 .credo.exs                                         |     34 +
 assets/vendor/vega-embed.js                        |    209 +
 lib/metric_flow/ai/ai_repository.ex                |     40 +-
 lib/metric_flow/correlations.ex                    |      2 +-
 .../correlations/correlations_repository.ex        |     77 +-
 lib/metric_flow/invitations.ex                     |     62 +-
 .../controllers/page_html/home.html.heex           |      2 +
 lib/metric_flow_web/live/correlation_live/goals.ex |    192 +
 lib/metric_flow_web/live/dashboard_live/show.ex    |     22 +-
 lib/metric_flow_web/live/invitation_live/send.ex   |     20 +-
 priv/repo/qa_seeds.exs                             |      6 +
 priv/repo/qa_seeds_448.exs                         |     59 +
 .../strategies/quick_books_o_auth2_test.exs        |     90 +
 .../live/correlation_live/goals_test.exs           |    508 +
 ...ser_can_view_list_of_all_saved_reports_spex.exs |    114 +
 ...s_goal_metrics_configuration_from_menu_spex.exs |     52 +
 ...relation_analysis_from_main_navigation_spex.exs |     77 +
 ...sitive_and_top_5_negative_correlations_spex.exs |     85 +
 376 files changed, 192444 insertions(+), 65866 deletions(-)
## 0d35662 - Implement ReportGenerator, Visualizations index, Goals LiveView, and fix QA issues

Date: 2026-03-18 23:26:49 -0400
Author: John Davenport


 .../spec/metric_flow/dashboards/dashboard.spec.md  |   2 +-
 .../dashboards/dashboard_visualization.spec.md     |   2 +-
 .../metric_flow/dashboards/visualization.spec.md   |   2 +-
 .../metric_flow_web/correlation_live/goals.spec.md |  50 +++++-
 assets/js/hooks/vega_lite.js                       |   2 +-
 lib/metric_flow/dashboards.ex                      |  17 +++
 lib/metric_flow_web/components/layouts.ex          |   2 +
 .../live/ai_live/report_generator.ex               |  65 ++++----
 lib/metric_flow_web/live/correlation_live/index.ex |   8 +
 .../live/visualization_live/editor.ex              |   8 +-
 .../live/visualization_live/index.ex               | 169 +++++++++++++++++++++
 lib/metric_flow_web/router.ex                      |   2 +
 .../live/visualization_live/editor_test.exs        |  10 +-
 13 files changed, 293 insertions(+), 46 deletions(-)
## 7fd29c6 - Architecture redesign: multi-series dashboard, updated specs, QA artifacts

Date: 2026-03-18 17:16:30 -0400
Author: John Davenport


 .code_my_spec/architecture/dependency_graph.mmd    |     25 +
 .code_my_spec/architecture/namespace_hierarchy.md  |     49 +-
 .code_my_spec/architecture/overview.md             |     82 +-
 .code_my_spec/internal/agent_test_events.json      | 133182 ++++++++++++++----
 ...40-email_notification_for_expired_token_not_.md |     25 +
 ...40-seed_script_creates_integration_with_refr.md |     31 +
 ...40-sync_now_on_expired_integration_shows_wro.md |     26 +
 ...13-criterion_4797_filter_assertion_is_too_br.md |     22 +
 ...18-older_failed_entries_expose_internal_elix.md |     21 +
 ...42-bdd_spec_brief_incorrectly_states_dashboa.md |     21 +
 .code_my_spec/qa/440/brief.md                      |    118 +
 .code_my_spec/qa/440/result_complete.md            |    103 +
 .../qa/440/result_failed_20260318_041104.md        |    127 +
 .../qa/440/result_failed_20260318_042831.md        |    163 +
 .../screenshots/01_integrations_page_connected.png |    Bin 0 -> 43680 bytes
 .../screenshots/02_sync_expired_flash_error.png    |    Bin 0 -> 46508 bytes
 .../03_detail_page_reconnect_button.png            |    Bin 0 -> 39263 bytes
 .../screenshots/04_data_preserved_after_expiry.png |    Bin 0 -> 45420 bytes
 .../qa/440/screenshots/05_reconnect_oauth_href.png |    Bin 0 -> 39263 bytes
 .../qa/440/screenshots/06_dev_mailbox.png          |    Bin 0 -> 26747 bytes
 .code_my_spec/qa/442/brief.md                      |    107 +
 .code_my_spec/qa/442/result_complete.md            |    130 +
 .../qa/442/result_failed_20260318_145856.md        |    126 +
 .../01-visualizations-new-page-load.png            |    Bin 0 -> 76880 bytes
 .../qa/442/screenshots/02-chart-type-selector.png  |    Bin 0 -> 42672 bytes
 .../qa/442/screenshots/03-line-selected.png        |    Bin 0 -> 35875 bytes
 .../qa/442/screenshots/04-bar-selected.png         |    Bin 0 -> 35868 bytes
 .../qa/442/screenshots/05-area-selected.png        |    Bin 0 -> 35850 bytes
 .../442/screenshots/06-default-line-selected.png   |    Bin 0 -> 42672 bytes
 .../442/screenshots/07-unauth-redirect-login.png   |    Bin 0 -> 30178 bytes
 .../qa/442/screenshots/08-dashboards-new.png       |    Bin 0 -> 58815 bytes
 .../screenshots/09-save-without-name-metric.png    |    Bin 0 -> 39625 bytes
 .../qa/442/screenshots/10-save-without-metric.png  |    Bin 0 -> 39833 bytes
 .../442/screenshots/11-preview-chart-rendered.png  |    Bin 0 -> 73037 bytes
 .../qa/442/screenshots/scenario_1_page_load.png    |    Bin 0 -> 76880 bytes
 .../screenshots/scenario_2_chart_type_selector.png |    Bin 0 -> 42822 bytes
 .../442/screenshots/scenario_3_line_selected.png   |    Bin 0 -> 35875 bytes
 .../qa/442/screenshots/scenario_4_bar_selected.png |    Bin 0 -> 35868 bytes
 .../442/screenshots/scenario_5_area_selected.png   |    Bin 0 -> 35850 bytes
 .../scenario_6_default_line_selected.png           |    Bin 0 -> 42672 bytes
 .../442/screenshots/scenario_7_unauth_redirect.png |    Bin 0 -> 28408 bytes
 .../442/screenshots/scenario_8_dashboards_new.png  |    Bin 0 -> 58815 bytes
 .../scenario_8_dashboards_new_after_add.png        |    Bin 0 -> 93641 bytes
 .code_my_spec/qa/444/brief.md                      |    115 +
 .code_my_spec/qa/444/result_complete.md            |    113 +
 .../qa/444/screenshots/scenario_1_page_loads.png   |    Bin 0 -> 47797 bytes
 .../scenario_2_canned_dashboards_section.png       |    Bin 0 -> 47797 bytes
 .../screenshots/scenario_3_marketing_overview.png  |    Bin 0 -> 47797 bytes
 .../screenshots/scenario_4_revenue_analysis.png    |    Bin 0 -> 47797 bytes
 .../screenshots/scenario_5_platform_comparison.png |    Bin 0 -> 47797 bytes
 .../screenshots/scenario_6_multiple_templates.png  |    Bin 0 -> 47797 bytes
 .../scenario_7_unauthenticated_redirect.png        |    Bin 0 -> 28408 bytes
 .../scenario_8_user_dashboards_section.png         |    Bin 0 -> 46096 bytes
 .../screenshots/scenario_9_new_dashboard_btn.png   |    Bin 0 -> 46096 bytes
 .code_my_spec/qa/452/brief.md                      |    125 +
 .code_my_spec/qa/453/result_complete.md            |    161 +
 .../qa/453/result_failed_20260318_134216.md        |    179 +
 .../01_settings_page_white_label_section.png       |    Bin 0 -> 35767 bytes
 .../qa/453/screenshots/02_save_png_logo_url.png    |    Bin 0 -> 39157 bytes
 .../qa/453/screenshots/03_save_jpg_logo_url.png    |    Bin 0 -> 35767 bytes
 .../qa/453/screenshots/04_save_svg_logo_url.png    |    Bin 0 -> 40593 bytes
 .../qa/453/screenshots/05_save_color_scheme.png    |    Bin 0 -> 35311 bytes
 .../screenshots/06_live_preview_before_save.png    |    Bin 0 -> 26390 bytes
 .../qa/453/screenshots/07_save_subdomain.png       |    Bin 0 -> 41855 bytes
 .../08_subdomain_persists_on_revisit.png           |    Bin 0 -> 32553 bytes
 .../screenshots/09_dns_verification_section.png    |    Bin 0 -> 32553 bytes
 .../qa/453/screenshots/10_reset_button_visible.png |    Bin 0 -> 32553 bytes
 .../453/screenshots/11_after_reset_to_default.png  |    Bin 0 -> 28192 bytes
 .../12_settings_persist_across_navigation.png      |    Bin 0 -> 36133 bytes
 .../13_no_anderson_analytics_branding.png          |    Bin 0 -> 45017 bytes
 .../bug_update_blocked_by_phx_change.png           |    Bin 0 -> 35684 bytes
 .../453/screenshots/s10_reset_button_visible.png   |    Bin 0 -> 32553 bytes
 .../453/screenshots/s11_after_reset_to_default.png |    Bin 0 -> 28192 bytes
 .../s12_settings_persist_across_navigation.png     |    Bin 0 -> 36133 bytes
 .../s13_no_anderson_analytics_dashboard.png        |    Bin 0 -> 45017 bytes
 .../s13_no_anderson_analytics_settings.png         |    Bin 0 -> 36133 bytes
 .../qa/453/screenshots/s1_white_label_section.png  |    Bin 0 -> 40489 bytes
 .../qa/453/screenshots/s2_save_png_logo_url.png    |    Bin 0 -> 40824 bytes
 .../s3_jpg_url_retained_after_phx_change.png       |    Bin 0 -> 31288 bytes
 .../qa/453/screenshots/s3_save_jpg_logo_url.png    |    Bin 0 -> 46199 bytes
 .../qa/453/screenshots/s4_save_svg_logo_url.png    |    Bin 0 -> 39898 bytes
 .../qa/453/screenshots/s5_save_color_scheme.png    |    Bin 0 -> 35311 bytes
 .../screenshots/s6_live_preview_before_save.png    |    Bin 0 -> 26259 bytes
 .../qa/453/screenshots/s7_save_subdomain.png       |    Bin 0 -> 41855 bytes
 .../s8_subdomain_persists_on_revisit.png           |    Bin 0 -> 32553 bytes
 .../screenshots/s9_dns_verification_section.png    |    Bin 0 -> 32553 bytes
 .code_my_spec/qa/518/brief.md                      |    137 +
 .code_my_spec/qa/518/result_complete.md            |    149 +
 .../qa/518/screenshots/screenshot_01_page_load.png |    Bin 0 -> 52864 bytes
 .../screenshot_02_connect_page_quickbooks.png      |    Bin 0 -> 35476 bytes
 .../518/screenshots/screenshot_03_empty_state.png  |    Bin 0 -> 52864 bytes
 .../screenshot_04_sync_history_entries.png         |    Bin 0 -> 52864 bytes
 .../screenshots/screenshot_05_filter_failed.png    |    Bin 0 -> 55932 bytes
 .../screenshots/screenshot_06_filter_success.png   |    Bin 0 -> 65202 bytes
 .../screenshots/screenshot_07_schedule_card.png    |    Bin 0 -> 65265 bytes
 .../screenshot_08_no_location_filter.png           |    Bin 0 -> 65265 bytes
 .../518/screenshots/screenshot_09_failed_entry.png |    Bin 0 -> 42644 bytes
 .../screenshot_10_old_failed_entries.png           |    Bin 0 -> 46091 bytes
 .../metric_flow/dashboards/query_builder.spec.md   |    111 +
 .../data_providers/google_business_profile.spec.md |     14 +
 .../data_providers/google_search_console.spec.md   |     14 +
 .../integrations/facebook_ads_accounts.spec.md     |     55 +
 .../integrations/google_ads_accounts.spec.md       |     53 +
 .../google_search_console_sites.spec.md            |     54 +
 .../integrations/oauth_state_store.spec.md         |     14 +
 .../integrations/providers/google_ads.spec.md      |     89 +
 .../providers/google_analytics.spec.md             |     88 +
 .../providers/google_search_console.spec.md        |     83 +
 .../integrations/quick_books_accounts.spec.md      |     59 +
 .../strategies/quick_books_o_auth2.spec.md         |     60 +
 .../ai_live/report_generator.spec.md               |     79 +-
 .../metric_flow_web/dashboard_live/index.spec.md   |     56 +-
 .code_my_spec/status/implementation_status.json    |      2 +-
 .code_my_spec/status/metric_flow.md                |      6 +-
 .code_my_spec/status/metric_flow/dashboards.md     |     10 +
 .code_my_spec/status/metric_flow/data_sync.md      |     22 +-
 .code_my_spec/status/metric_flow/integrations.md   |     92 +-
 .../integrations/quick_books_accounts.md           |      8 +
 .../integrations/strategies/quick_books_o_auth2.md |      8 +
 .code_my_spec/status/metric_flow_web.md            |     25 +-
 .../status/metric_flow_web/active_account_hook.md  |      7 +-
 .code_my_spec/status/metric_flow_web/ai_live.md    |     28 +-
 .../metric_flow_web/ai_live/report_generator.md    |      9 +
 .../status/metric_flow_web/core_components.md      |      7 +-
 .../status/metric_flow_web/correlation_live.md     |     11 +
 .../status/metric_flow_web/dashboard_live.md       |     28 +-
 .../status/metric_flow_web/dashboard_live/index.md |      9 +
 .code_my_spec/status/metric_flow_web/error_html.md |      7 +-
 .code_my_spec/status/metric_flow_web/error_json.md |      7 +-
 .../status/metric_flow_web/health_controller.md    |      7 +-
 .../integration_o_auth_controller.md               |      7 +-
 .code_my_spec/status/metric_flow_web/layouts.md    |      7 +-
 .../status/metric_flow_web/onboarding_live.md      |      7 +-
 .../status/metric_flow_web/page_controller.md      |      7 +-
 .code_my_spec/status/metric_flow_web/page_html.md  |      7 +-
 .../metric_flow_web/user_session_controller.md     |      7 +-
 .../status/metric_flow_web/visualization_live.md   |      6 +-
 .../metric_flow_web/visualization_live/editor.md   |      9 +
 .../status/metric_flow_web/white_label_hook.md     |      7 +-
 .code_my_spec/status/stories.md                    |     36 +-
 .../dashboards/chart_builder_component_test.md     |     60 +
 .../chart_builder_component_test_problems.md       |      2 +
 .../dashboards/dashboard_component_code.md         |     29 +
 .../dashboard_component_code_problems.md           |      1 +
 .../dashboard_visualization_component_code.md      |     29 +
 ...hboard_visualization_component_code_problems.md |      1 +
 .../dashboards/dashboards_component_test.md        |     60 +
 .../dashboards_component_test_problems.md          |      2 +
 .../dashboards_context_implementation.md           |     22 +
 .../dashboards_context_implementation_problems.md  |      1 +
 .../dashboards/query_builder_component_code.md     |     74 +
 .../query_builder_component_code_problems.md       |      2 +
 .../dashboards/query_builder_component_test.md     |     62 +
 .../query_builder_component_test_problems.md       |      2 +
 .../dashboards/visualization_component_code.md     |     29 +
 .../visualization_component_code_problems.md       |      1 +
 .../facebook_ads_accounts_component_spec.md        |    143 +
 ...acebook_ads_accounts_component_spec_problems.md |      3 +
 .../google_ads_accounts_component_spec.md          |    143 +
 .../google_ads_accounts_component_spec_problems.md |      3 +
 .../integrations/google_ads_component_spec.md      |    143 +
 .../google_ads_component_spec_problems.md          |      3 +
 .../google_analytics_component_spec.md             |    143 +
 .../google_analytics_component_spec_problems.md    |      3 +
 .../google_search_console_component_spec.md        |    143 +
 ...oogle_search_console_component_spec_problems.md |      3 +
 .../google_search_console_sites_component_spec.md  |    143 +
 ...search_console_sites_component_spec_problems.md |      3 +
 .../quick_books_accounts_component_spec.md         |    143 +
 ...quick_books_accounts_component_spec_problems.md |      3 +
 .../quick_books_o_auth2_component_spec.md          |    143 +
 .../quick_books_o_auth2_component_spec_problems.md |      3 +
 .../report_generator_component_code.md             |    127 +
 .../report_generator_component_code_problems.md    |      2 +
 .../report_generator_component_test.md             |     62 +
 .../report_generator_component_test_problems.md    |      2 +
 .../report_generator_live_view_spec.md             |    206 +
 .../report_generator_live_view_spec_problems.md    |      2 +
 .../dashboard_live/index/index_component_code.md   |    127 +
 .../index/index_component_code_problems.md         |      2 +
 .../dashboard_live/index/index_component_test.md   |     62 +
 .../index/index_component_test_problems.md         |      2 +
 .../dashboard_live/index/index_live_view_spec.md   |    206 +
 .../index/index_live_view_spec_problems.md         |      2 +
 .../integration_live/index/index_component_code.md |    127 +
 .../index/index_component_code_problems.md         |     24 +
 .../editor/editor_component_code.md                |    127 +
 .../editor/editor_component_code_problems.md       |      2 +
 .../editor/editor_component_test.md                |     62 +
 .../editor/editor_component_test_problems.md       |      2 +
 .../editor/editor_live_view_spec.md                |    206 +
 .../editor/editor_live_view_spec_problems.md       |      2 +
 .code_my_spec/tasks/qa/story_452_qa_story.md       |    146 +
 .../440/subagent_prompts/bdd_specs_prompt.md       |    729 +
 .code_my_spec/tasks/stories/440/write_bdd_specs.md |     22 +
 .../442/subagent_prompts/bdd_specs_prompt.md       |    729 +
 .code_my_spec/tasks/stories/442/write_bdd_specs.md |     22 +
 .../452/subagent_prompts/bdd_specs_prompt.md       |    754 +
 .code_my_spec/tasks/stories/452/write_bdd_specs.md |     22 +
 lib/metric_flow/dashboards/chart_builder.ex        |     39 +-
 .../dashboards/dashboards_repository.ex            |     21 +-
 lib/metric_flow/dashboards/query_builder.ex        |    117 +
 lib/metric_flow_web/live/agency_live/settings.ex   |     17 +-
 .../live/ai_live/report_generator.ex               |    330 +
 lib/metric_flow_web/live/dashboard_live/index.ex   |    191 +
 .../live/visualization_live/editor.ex              |    391 +
 lib/metric_flow_web/router.ex                      |      1 +
 priv/repo/qa_seeds_440.exs                         |     75 +
 priv/repo/qa_seeds_444.exs                         |     95 +
 test/cassettes/ai/report_generator_success.json    |    172 +
 .../data_sync/quickbooks_fetch_metrics.json        |    352 +-
 .../data_sync/quickbooks_unauthorized.json         |     96 +-
 test/metric_flow/dashboards/chart_builder_test.exs |     61 +
 test/metric_flow/dashboards/dashboard_test.exs     |     43 +-
 .../dashboards/dashboard_visualization_test.exs    |     46 +-
 test/metric_flow/dashboards/query_builder_test.exs |    280 +
 test/metric_flow/dashboards/visualization_test.exs |     44 +-
 test/metric_flow/dashboards_test.exs               |     78 +
 .../live/ai_live/report_generator_test.exs         |    280 +
 .../live/dashboard_live/index_test.exs             |    493 +
 .../live/visualization_live/editor_test.exs        |    549 +
 ...n_status_changes_to_needs_reconnection_spex.exs |    105 +
 ..._line_bar_donut_gantt_scatter_area_etc_spex.exs |    155 +
 ...w_revenue_analysis_platform_comparison_spex.exs |    133 +
 ...language_description_of_desired_report_spex.exs |    134 +
 225 files changed, 121007 insertions(+), 25173 deletions(-)
## 6de30d6 - Redesign dashboard with multi-series Vega-Lite chart, data table, and date controls

Date: 2026-03-18 14:36:00 -0400
Author: John Davenport


 .code_my_spec/architecture/proposal.md             |  365 +++----
 .code_my_spec/spec/metric_flow/dashboards.spec.md  |   39 +-
 .../metric_flow/dashboards/chart_builder.spec.md   |   56 +-
 .../metric_flow_web/dashboard_live/show.spec.md    |   65 +-
 .../visualization_live/editor.spec.md              |   65 +-
 assets/js/app.js                                   |    3 +-
 assets/js/hooks/vega_lite.js                       |   28 +
 assets/js/theme.js                                 |   17 +
 assets/package-lock.json                           | 1074 ++++++++++++++++++++
 assets/package.json                                |   18 +
 lib/metric_flow/dashboards.ex                      |   93 +-
 lib/metric_flow/dashboards/chart_builder.ex        |   63 +-
 .../components/layouts/root.html.heex              |   21 +-
 lib/metric_flow_web/live/dashboard_live/show.ex    |  605 ++++++-----
 lib/metric_flow_web/router.ex                      |   10 +-
 test/metric_flow/dashboards/chart_builder_test.exs |  109 ++
 .../live/dashboard_live/show_test.exs              |   28 +-
 17 files changed, 2160 insertions(+), 499 deletions(-)
## 4097b58 - Add account pickers for all providers, expand backfill to 548 days, fix QuickBooks sandbox

Date: 2026-03-17 23:10:08 -0400
Author: John Davenport


 .../data_sync/data_providers/facebook_ads.ex       | 17 +++-
 .../data_sync/data_providers/google_ads.ex         |  2 +-
 .../data_sync/data_providers/google_analytics.ex   |  2 +-
 .../data_providers/google_search_console.ex        |  2 +-
 .../data_sync/data_providers/quick_books.ex        | 19 ++++-
 lib/metric_flow/integrations.ex                    | 24 ++++++
 .../integrations/facebook_ads_accounts.ex          | 84 ++++++++++++++++++++
 .../integrations/quickbooks_accounts.ex            | 90 ++++++++++++++++++++++
 .../live/integration_live/connect.ex               | 20 +++++
 lib/metric_flow_web/live/integration_live/index.ex | 15 +++-
 10 files changed, 262 insertions(+), 13 deletions(-)
## 097dbd3 - Split Google OAuth into separate providers, fix QuickBooks OAuth, implement GSC sync

Date: 2026-03-17 22:53:49 -0400
Author: John Davenport


 lib/metric_flow/correlations/correlation_result.ex |   2 +-
 .../data_providers/google_search_console.ex        | 212 +++++++++++++++++++++
 lib/metric_flow/data_sync/sync_history.ex          |   2 +-
 lib/metric_flow/data_sync/sync_job.ex              |   2 +-
 lib/metric_flow/data_sync/sync_worker.ex           |   3 +
 lib/metric_flow/integrations.ex                    |  36 +++-
 .../integrations/google_ads_accounts.ex            | 144 ++++++++++++++
 .../integrations/google_search_console_sites.ex    |  78 ++++++++
 lib/metric_flow/integrations/integration.ex        |   3 +
 lib/metric_flow/integrations/o_auth_state_store.ex |  18 +-
 .../integrations/providers/google_ads.ex           |  42 ++++
 .../integrations/providers/google_analytics.ex     |  42 ++++
 .../providers/google_search_console.ex             |  42 ++++
 lib/metric_flow/metrics/metric.ex                  |   2 +-
 .../live/integration_live/connect.ex               |  87 ++++++---
 lib/metric_flow_web/live/integration_live/index.ex |  58 ++++--
 priv/repo/qa_seeds.exs                             |  78 +++++---
 .../integrations/providers/quick_books_test.exs    |  24 ++-
 .../live/integration_live/index_test.exs           |  72 +++----
 19 files changed, 818 insertions(+), 129 deletions(-)
## 0b7620b - Add BDD specs for sync stories, fix QuickBooks OAuth, resolve QA issues

Date: 2026-03-17 21:49:32 -0400
Author: John Davenport


 .code_my_spec/config.yml                           |     2 +-
 .code_my_spec/internal/agent_test_events.json      | 50040 +++++++++++--------
 ...mp-integrations_index_and_connect_pages_have.md |    25 +
 ...mp-no_obvious_way_to_invite_or_add_team_memb.md |    25 +
 ...mp-no_way_to_select_google_analytics_propert.md |    25 +
 ...mp-refactor_integrations_architecture_separa.md |    25 +
 ...25-logged_out_successfully_flash_never_displ.md |    44 +
 ...25-post_users_log_in_with_email_only_body_re.md |     9 +-
 ...25-welcome_back_flash_not_shown_after_passwo.md |    36 +
 ...26-admin_invite_form_shows_admin_role_option.md |    30 +
 ...26-qa_database_role_drift_qa_example_com_is_.md |    38 +
 ...26-role_change_via_inline_select_still_drops.md |    32 +
 ...26-role_change_via_phx_change_select_does_no.md |    33 +
 ...26-seed_data_role_drift_causes_test_failures.md |    35 +
 ...27-role_change_via_phx_change_select_does_no.md |    16 +-
 ...29-bdd_spex_route_uses_invitations_token_acc.md |     8 +-
 ...30-invite_form_role_select_defaults_to_owner.md |    30 +
 ...30-seeds_cannot_be_re_run_while_phoenix_serv.md |    25 +
 ...31-account_switch_does_not_persist_across_pa.md |    25 +
 ...31-accountlive_index_does_not_display_agency.md |    13 +-
 ...31-accountlive_index_missing_switch_account_.md |    15 +-
 ...31-active_account_defaults_to_most_recently_.md |    25 +
 ...31-current_account_name_missing_from_most_au.md |    25 +
 ...31-members_list_and_member_rows_missing_data.md |    12 +-
 ...31-navigation_missing_current_account_name_i.md |    12 +-
 ...31-read_only_and_account_manager_users_can_s.md |    11 +-
 ...31-switch_account_button_shows_account_name_.md |    25 +
 ...33-ownership_transfer_new_owner_cannot_see_t.md |    11 +-
 ...34-account_selection_page_uses_radio_buttons.md |    25 +
 ...34-bdd_spec_references_google_ads_provider_r.md |    25 +
 ...34-facebook_and_quickbooks_accounts_pages_sh.md |    25 +
 ...34-non_google_provider_account_selection_pag.md |    25 +
 ...34-oauth_callback_does_not_display_error_des.md |    21 +
 ...34-oauth_callback_is_a_controller_redirect_n.md |    35 +
 ...34-oauth_callback_with_code_returns_misleadi.md |    31 +
 ...34-oauth_connect_button_not_rendered_when_pr.md |    30 +
 ...34-visiting_integrations_connect_provider_wi.md |    30 +
 ...35-connected_integration_has_no_reconnect_bu.md |    30 +
 ...35-oauth_callback_crashes_with_500_on_missin.md |    30 +
 ...35-oauth_error_callbacks_show_flash_message_.md |    30 +
 ...36-confirm_button_in_disconnect_modal_labele.md |    25 +
 ...36-connect_button_initiates_oauth_redirect_i.md |    25 +
 ...36-disconnect_confirmation_uses_inline_panel.md |    30 +
 ...36-disconnect_flash_message_missing_no_new_d.md |    28 +
 ...36-disconnect_modal_heading_does_not_include.md |    28 +
 ...36-disconnect_warning_paragraph_missing_data.md |    28 +
 ...36-google_ads_integration_seed_cannot_be_run.md |     9 +-
 ...36-google_ads_is_not_a_registered_provider_s.md |    30 +
 ...36-save_button_on_edit_accounts_page_missing.md |    21 +
 ...37-qa_seed_script_does_not_clear_existing_sy.md |    25 +
 ...38-google_sync_fails_with_database_truncatio.md |    34 +
 ...38-seed_data_drift_stale_integrations_from_p.md |    21 +
 ...38-sync_failed_for_google_all_providers_fail.md |    21 +
 ...38-sync_failure_flash_message_exposes_raw_el.md |    36 +
 ...38-sync_failure_flash_message_is_generic_ins.md |    35 +
 ...38-sync_now_button_never_enters_disabled_in_.md |    39 +
 ...38-syncjob_schema_rejects_google_provider_cr.md |    30 +
 ...41-google_analytics_metrics_classified_as_pl.md |    25 +
 ...41-no_top_level_dashboard_route_bdd_specs_re.md |    26 -
 ...41-platform_filter_active_state_broken_for_g.md |    11 +-
 ...43-cancel_link_and_not_found_redirect_use_wr.md |    31 +
 ...43-name_validation_error_shown_on_fresh_page.md |    30 +
 ...43-vibium_cannot_trigger_phx_change_on_stand.md |    31 +
 ...55-deletion_confirmation_email_is_never_sent.md |    41 +
 ...55-invite_form_role_selection_ignored_member.md |    52 +
 ...55-role_change_select_fires_on_first_user_in.md |    55 +
 ...93-seed_script_fails_in_sandbox_cloudflaretu.md |    26 -
 ...95-bdd_spex_suite_cannot_run_owner_with_inte.md |    11 +-
 ...09-criterion_4761_spex_fails_to_compile_due_.md |    25 +
 ...09-spex_criterion_4761_filename_exceeds_erla.md |    25 +
 ...09-sync_history_entries_show_provider_google.md |    25 +
 ...16-criterion_4807_spex_whenstep_discards_con.md |    27 +
 ...16-google_search_console_not_registered_in_p.md |    25 +
 ...17-google_business_and_google_business_revie.md |    25 +
 ...17-schedule_section_does_not_mention_google_.md |    25 +
 ...17-spex_criterion_4819_and_4827_fail_to_load.md |    25 +
 ...36-confirm_disconnect_button_labeled_confirm.md |    21 -
 ...36-connect_button_initiates_oauth_instead_of.md |    21 -
 ...36-disconnect_confirmation_uses_inline_panel.md |    21 -
 ...36-disconnect_flash_message_missing_no_new_d.md |    21 -
 ...38-sync_now_button_never_triggers_actual_dat.md |    21 -
 ...39-bdd_spex_reference_owner_with_integration.md |    29 -
 ...39-seed_script_fails_in_sandbox_due_to_cloud.md |    27 -
 ...13-criterion_4797_filter_assertion_is_too_br.md |    22 +
 ...17-seed_script_does_not_clear_sync_history_e.md |    21 +
 .../qa/424/{result.md => result_complete.md}       |     0
 .code_my_spec/qa/425/brief.md                      |    36 +-
 .code_my_spec/qa/425/result_complete.md            |   161 +
 ...{result.md => result_failed_20260315_173638.md} |     0
 .../qa/425/result_failed_20260315_175204.md        |   276 +
 .../qa/425/result_failed_20260315_182217.md        |   159 +
 .code_my_spec/qa/425/screenshots/01_login_page.png |   Bin 0 -> 43169 bytes
 .../qa/425/screenshots/02_login_success.png        |   Bin 0 -> 39489 bytes
 .../qa/425/screenshots/03_magic_link_sent.png      |   Bin 0 -> 33800 bytes
 .../screenshots/04_login_error_wrong_password.png  |   Bin 0 -> 29467 bytes
 .../screenshots/05_login_error_unregistered.png    |   Bin 0 -> 30197 bytes
 .../qa/425/screenshots/06_login_error_empty.png    |   Bin 0 -> 24463 bytes
 .../425/screenshots/07_settings_authenticated.png  |   Bin 0 -> 24391 bytes
 .../425/screenshots/08_accounts_authenticated.png  |   Bin 0 -> 23694 bytes
 .../screenshots/09_settings_with_logout_link.png   |   Bin 0 -> 24391 bytes
 .code_my_spec/qa/425/screenshots/10_logged_out.png |   Bin 0 -> 27609 bytes
 .../qa/425/screenshots/11_post_logout_redirect.png |   Bin 0 -> 28408 bytes
 .../screenshots/12_unauthenticated_redirect.png    |   Bin 0 -> 28396 bytes
 .../qa/425/screenshots/13_remember_me_buttons.png  |   Bin 0 -> 43157 bytes
 .../qa/425/screenshots/14_remember_me_cookie.png   |   Bin 0 -> 22622 bytes
 .../screenshots/14_remember_me_login_success.png   |   Bin 0 -> 76754 bytes
 .../425/screenshots/15_no_remember_me_cookie.png   |   Bin 0 -> 39489 bytes
 .code_my_spec/qa/426/result_complete.md            |   178 +
 ...{result.md => result_failed_20260315_220104.md} |     0
 .../qa/426/result_failed_20260315_222452.md        |   152 +
 .../qa/426/result_failed_20260315_225141.md        |   206 +
 .../qa/426/result_failed_20260315_231507.md        |   185 +
 .../qa/426/screenshots/01_members_page_final.png   |   Bin 0 -> 87911 bytes
 .../qa/426/screenshots/01_members_page_owner.png   |   Bin 0 -> 38555 bytes
 .../01_members_page_owner_corrected.png            |   Bin 0 -> 27821 bytes
 .../qa/426/screenshots/02_invite_form_visible.png  |   Bin 0 -> 38555 bytes
 .../qa/426/screenshots/03_invite_success.png       |   Bin 0 -> 28233 bytes
 .../screenshots/04_invite_user_not_found_error.png |   Bin 0 -> 26725 bytes
 .../qa/426/screenshots/05_role_options_owner.png   |   Bin 0 -> 26725 bytes
 .../05_role_options_owner_corrected.png            |   Bin 0 -> 27821 bytes
 .../qa/426/screenshots/06_invite_as_admin.png      |   Bin 0 -> 28021 bytes
 .../426/screenshots/06_invite_as_admin_result.png  |   Bin 0 -> 33977 bytes
 .../06_invite_as_admin_unauthorized.png            |   Bin 0 -> 30812 bytes
 .../qa/426/screenshots/07_before_role_change.png   |   Bin 0 -> 38293 bytes
 .../qa/426/screenshots/07_role_change_failed.png   |   Bin 0 -> 31244 bytes
 .../qa/426/screenshots/07_role_change_select.png   |   Bin 0 -> 25389 bytes
 .../qa/426/screenshots/07_role_change_success.png  |   Bin 0 -> 26797 bytes
 .../426/screenshots/08_last_owner_protection.png   |   Bin 0 -> 27739 bytes
 .../qa/426/screenshots/09_member_removed.png       |   Bin 0 -> 25803 bytes
 .../qa/426/screenshots/10_readonly_member_view.png |   Bin 0 -> 21427 bytes
 .../screenshots/11_isolation_separate_account.png  |   Bin 0 -> 21427 bytes
 .../qa/426/screenshots/12_already_member_error.png |   Bin 0 -> 29494 bytes
 .../qa/426/screenshots/13_final_state.png          |   Bin 0 -> 87303 bytes
 .code_my_spec/qa/427/result_complete.md            |   119 +
 ...{result.md => result_failed_20260316_173034.md} |     0
 .code_my_spec/qa/430/result_complete.md            |   111 +
 ...{result.md => result_failed_20260316_012246.md} |     0
 .../qa/430/result_failed_20260316_015007.md        |   122 +
 .../qa/430/result_failed_20260316_024914.md        |   149 +
 .../430/screenshots/01-members-list-owner-view.png |   Bin 31737 -> 26484 bytes
 .../qa/430/screenshots/02-member-row-fields.png    |   Bin 32898 -> 26484 bytes
 .../screenshots/03-after-invite-two-members.png    |   Bin 32898 -> 31916 bytes
 .../430/screenshots/04-role-change-confirmed.png   |   Bin 0 -> 30786 bytes
 .../qa/430/screenshots/05-member-removed.png       |   Bin 22459 -> 27101 bytes
 .../qa/430/screenshots/06-owner-removed-member.png |   Bin 29969 -> 24664 bytes
 .../06-removed-member-access-denied.png            |   Bin 26279 -> 35430 bytes
 .../qa/430/screenshots/06a-after-reinvite.png      |   Bin 0 -> 31218 bytes
 .../06b-member-view-different-account.png          |   Bin 0 -> 35430 bytes
 .../screenshots/07-no-remove-for-sole-owner.png    |   Bin 32898 -> 33461 bytes
 .../screenshots/08-unauthenticated-redirect.png    |   Bin 31025 -> 28396 bytes
 .../430/screenshots/09-permission-change-flash.png |   Bin 29969 -> 24664 bytes
 .../screenshots/bug-invite-defaults-to-owner.png   |   Bin 0 -> 32001 bytes
 .code_my_spec/qa/431/result_complete.md            |   166 +
 ...{result.md => result_failed_20260316_175059.md} |     0
 .../qa/431/result_failed_20260316_181907.md        |   173 +
 .../qa/431/screenshots/01-accounts-page-owner.png  |   Bin 64854 -> 79784 bytes
 .../screenshots/02-after-switch-client-beta.png    |   Bin 0 -> 80979 bytes
 .../screenshots/03-current-account-name-nav.png    |   Bin 0 -> 41255 bytes
 .../431/screenshots/04-settings-readonly-user.png  |   Bin 0 -> 56574 bytes
 .../431/screenshots/05-members-readonly-user.png   |   Bin 0 -> 21993 bytes
 .../qa/431/screenshots/06-integrations-acctmgr.png |   Bin 0 -> 29888 bytes
 .../qa/431/screenshots/07-settings-acctmgr.png     |   Bin 0 -> 58621 bytes
 .../qa/431/screenshots/08-members-acctmgr.png      |   Bin 0 -> 22681 bytes
 .../qa/431/screenshots/09-settings-admin.png       |   Bin 0 -> 106093 bytes
 .../qa/431/screenshots/10-members-admin.png        |   Bin 0 -> 83163 bytes
 .../11-originator-vs-invited-badges.png            |   Bin 0 -> 79784 bytes
 .code_my_spec/qa/434/brief.md                      |   304 +-
 .code_my_spec/qa/434/result_complete.md            |   152 +
 ...{result.md => result_failed_20260316_034123.md} |     0
 .../qa/434/result_failed_20260316_035109.md        |   191 +
 .../qa/434/result_failed_20260316_041909.md        |   197 +
 .../qa/434/result_failed_20260316_044300.md        |   185 +
 .../qa/434/result_failed_20260316_232259.md        |   202 +
 .../qa/434/result_failed_20260317_001716.md        |   204 +
 .../qa/434/screenshots/01-platform-selection.png   |   Bin 0 -> 36560 bytes
 .../qa/434/screenshots/01_platform_selection.png   |   Bin 0 -> 33117 bytes
 .../screenshots/01b-platform-selection-final.png   |   Bin 0 -> 70959 bytes
 .../qa/434/screenshots/02-connect-buttons.png      |   Bin 0 -> 36560 bytes
 .../qa/434/screenshots/02_google_ads_detail.png    |   Bin 0 -> 38093 bytes
 .../screenshots/03-google-ads-detail-connected.png |   Bin 0 -> 38093 bytes
 .../qa/434/screenshots/03-google-detail.png        |   Bin 0 -> 36610 bytes
 .../03_account_selection_google_ads.png            |   Bin 0 -> 34860 bytes
 .../qa/434/screenshots/03b-facebook-detail.png     |   Bin 0 -> 32083 bytes
 .../03b-google-analytics-detail-not-connected.png  |   Bin 0 -> 35112 bytes
 .../04_account_selection_google_analytics.png      |   Bin 0 -> 35705 bytes
 .../qa/434/screenshots/05-google-accounts.png      |   Bin 0 -> 40371 bytes
 .../05-google-ads-account-selection.png            |   Bin 0 -> 34860 bytes
 .../qa/434/screenshots/05_callback_error_state.png |   Bin 0 -> 28859 bytes
 .../qa/434/screenshots/05b-facebook-accounts.png   |   Bin 0 -> 39502 bytes
 .../05b-google-analytics-account-selection.png     |   Bin 0 -> 35705 bytes
 .../434/screenshots/06-not-saved-before-oauth.png  |   Bin 0 -> 36610 bytes
 .../qa/434/screenshots/06_access_denied_error.png  |   Bin 0 -> 30226 bytes
 .../434/screenshots/07-callback-error-result.png   |   Bin 0 -> 32908 bytes
 .../qa/434/screenshots/07-callback-error-state.png |   Bin 0 -> 28859 bytes
 .../07_unauthenticated_redirect_curl_verified.png  |   Bin 0 -> 76754 bytes
 .../qa/434/screenshots/08-access-denied-error.png  |   Bin 0 -> 32908 bytes
 .../qa/434/screenshots/08_integrations_list.png    |   Bin 0 -> 41254 bytes
 .../screenshots/09-unauthenticated-redirect.png    |   Bin 0 -> 28408 bytes
 .../434/screenshots/09_extra_google_platform.png   |   Bin 0 -> 33117 bytes
 .../qa/434/screenshots/10-integrations-list.png    |   Bin 0 -> 41254 bytes
 .../qa/434/screenshots/10-integrations-scoped.png  |   Bin 0 -> 44315 bytes
 .../435/screenshots/scenario-01-platform-grid.png  |   Bin 0 -> 33445 bytes
 .../435/screenshots/scenario-03-connect-click.png  |   Bin 0 -> 33491 bytes
 .../scenario-03-connect-flash-error.png            |   Bin 0 -> 33491 bytes
 .../screenshots/scenario-05-quickbooks-detail.png  |   Bin 31508 -> 31577 bytes
 .../screenshots/scenario-06-account-selection.png  |   Bin 34692 -> 35142 bytes
 .../scenario-07-save-redirect-integrations.png     |   Bin 0 -> 42153 bytes
 .../scenario-08-access-denied-flash.png            |   Bin 0 -> 34980 bytes
 .../screenshots/scenario-09-server-error-flash.png |   Bin 0 -> 35197 bytes
 .../qa/435/screenshots/scenario-10-no-params.png   |   Bin 29889 -> 45393 bytes
 .../qa/435/screenshots/scenario-11-valid-code.png  |   Bin 28563 -> 45393 bytes
 .../screenshots/scenario-12-integrations-list.png  |   Bin 41593 -> 42153 bytes
 .code_my_spec/qa/436/brief.md                      |   302 +-
 .code_my_spec/qa/436/result.md                     |   265 +-
 .code_my_spec/qa/436/result_complete.md            |   147 +
 .../qa/436/result_failed_20260316_045522.md        |   202 +
 .../qa/436/result_failed_20260316_051902.md        |   219 +
 .../qa/436/result_failed_20260316_053357.md        |   262 +
 .../qa/436/result_failed_20260316_055119.md        |   288 +
 .../qa/436/result_failed_20260316_135725.md        |   270 +
 .../qa/436/result_failed_20260316_140730.md        |   252 +
 .../qa/436/result_failed_20260316_142930.md        |   184 +
 .code_my_spec/qa/436/screenshots/00-full-page.png  |   Bin 0 -> 81256 bytes
 .../screenshots/01-integrations-index-no-seed.png  |   Bin 0 -> 40523 bytes
 .../qa/436/screenshots/01-integrations-index.png   |   Bin 40503 -> 44931 bytes
 .../02-connected-and-available-sections.png        |   Bin 0 -> 106484 bytes
 .../screenshots/02-integrations-h1-connected.png   |   Bin 0 -> 43126 bytes
 .../screenshots/02-integrations-index-loaded.png   |   Bin 0 -> 82404 bytes
 .../qa/436/screenshots/03-disconnect-clicked.png   |   Bin 0 -> 40758 bytes
 .../screenshots/03-integration-platform-name.png   |   Bin 0 -> 42956 bytes
 .../screenshots/03-platform-name-date-status.png   |   Bin 0 -> 45104 bytes
 .../screenshots/04-disconnect-warning-panel.png    |   Bin 0 -> 40758 bytes
 .../qa/436/screenshots/04-selected-accounts.png    |   Bin 0 -> 44931 bytes
 .../qa/436/screenshots/05-disconnect-cancelled.png |   Bin 0 -> 44967 bytes
 .../qa/436/screenshots/05-edit-accounts-link.png   |   Bin 0 -> 44931 bytes
 .../qa/436/screenshots/05b-edit-accounts-page.png  |   Bin 0 -> 40147 bytes
 .../05c-edit-accounts-after-disconnect.png         |   Bin 0 -> 32951 bytes
 .../screenshots/06-disconnect-button-present.png   |   Bin 0 -> 44931 bytes
 .../screenshots/06-integration-disconnected.png    |   Bin 0 -> 46187 bytes
 .../06-integration-selected-accounts.png           |   Bin 0 -> 42956 bytes
 .../screenshots/07-disconnect-modal-warning.png    |   Bin 0 -> 76389 bytes
 .../qa/436/screenshots/07-reconnect-button.png     |   Bin 0 -> 46187 bytes
 .../qa/436/screenshots/08-connect-button-click.png |   Bin 0 -> 15892 bytes
 .../qa/436/screenshots/08-disconnect-cancelled.png |   Bin 0 -> 44931 bytes
 .../qa/436/screenshots/09-after-disconnect.png     |   Bin 0 -> 45379 bytes
 .../qa/436/screenshots/09-disconnect-modal.png     |   Bin 0 -> 70425 bytes
 .../screenshots/09-integrations-current-state.png  |   Bin 0 -> 80326 bytes
 .../qa/436/screenshots/10-quickbooks-detail.png    |   Bin 0 -> 41062 bytes
 .../qa/436/screenshots/10-reconnect-available.png  |   Bin 0 -> 45379 bytes
 .../qa/436/screenshots/10b-reconnect-navigated.png |   Bin 0 -> 36865 bytes
 .../qa/436/screenshots/11-disconnect-cancelled.png |   Bin 0 -> 42956 bytes
 .../screenshots/11-disconnect-modal-attempt.png    |   Bin 0 -> 41123 bytes
 .../qa/436/screenshots/11-uniform-card-layout.png  |   Bin 0 -> 92532 bytes
 .../qa/436/screenshots/12-final-state.png          |   Bin 0 -> 92532 bytes
 .../screenshots/12-integration-disconnected.png    |   Bin 0 -> 83251 bytes
 .../qa/436/screenshots/13-reconnect-button.png     |   Bin 0 -> 33782 bytes
 .../qa/436/screenshots/13-reconnect-redirected.png |   Bin 0 -> 36093 bytes
 .../qa/436/screenshots/14-available-platforms.png  |   Bin 0 -> 80249 bytes
 .../qa/436/screenshots/14-visual-states.png        |   Bin 0 -> 81256 bytes
 .../qa/436/screenshots/disconnect-cancelled.png    |   Bin 45426 -> 42956 bytes
 .../qa/436/screenshots/disconnect-modal.png        |   Bin 48106 -> 69417 bytes
 .../436/screenshots/integration-disconnected.png   |   Bin 45799 -> 80767 bytes
 .../436/screenshots/integration-platform-name.png  |   Bin 41113 -> 42956 bytes
 .../screenshots/integration-selected-accounts.png  |   Bin 84035 -> 42956 bytes
 .../qa/436/screenshots/integrations-index.png      |   Bin 41113 -> 81336 bytes
 .../qa/436/screenshots/reconnect-button.png        |   Bin 45799 -> 31294 bytes
 .code_my_spec/qa/437/result_complete.md            |   164 +
 .../qa/437/result_failed_20260316_191829.md        |   183 +
 .code_my_spec/qa/437/screenshots/01_page_load.png  |   Bin 49134 -> 49288 bytes
 .../qa/437/screenshots/02_schedule_section.png     |   Bin 49134 -> 49288 bytes
 .../qa/437/screenshots/03_providers_coverage.png   |   Bin 49134 -> 49288 bytes
 .code_my_spec/qa/437/screenshots/04_date_range.png |   Bin 49134 -> 49288 bytes
 .../qa/437/screenshots/05_empty_state.png          |   Bin 49134 -> 49288 bytes
 .../qa/437/screenshots/06_filter_buttons.png       |   Bin 49134 -> 49288 bytes
 .../qa/437/screenshots/07_filter_toggle.png        |   Bin 62156 -> 61747 bytes
 .../screenshots/09_metrics_financial_mention.png   |   Bin 62156 -> 61747 bytes
 .code_my_spec/qa/437/screenshots/10_full_page.png  |   Bin 82242 -> 89307 bytes
 .code_my_spec/qa/438/brief.md                      |   163 +-
 .code_my_spec/qa/438/result.md                     |   123 +-
 .code_my_spec/qa/438/result_complete.md            |   133 +
 .../qa/438/result_failed_20260316_144843.md        |    95 +
 .../qa/438/result_failed_20260316_150810.md        |   100 +
 .../qa/438/result_failed_20260316_152749.md        |   115 +
 .../qa/438/result_failed_20260316_153820.md        |   109 +
 .../qa/438/result_failed_20260316_155123.md        |   107 +
 .../qa/438/result_failed_20260316_161204.md        |   105 +
 .../qa/438/result_failed_20260316_162152.md        |   105 +
 .../qa/438/result_failed_20260317_032954.md        |   140 +
 .../qa/438/result_failed_20260317_042849.md        |   146 +
 .../qa/438/result_failed_20260317_140901.md        |   133 +
 .../qa/438/result_failed_20260317_153013.md        |   138 +
 .../qa/438/result_failed_20260317_154523.md        |   195 +
 .../qa/438/screenshots/01-integrations-page.png    |   Bin 0 -> 107092 bytes
 .../qa/438/screenshots/02-sync-button-enabled.png  |   Bin 42153 -> 107092 bytes
 .../qa/438/screenshots/03-after-sync-click.png     |   Bin 0 -> 60658 bytes
 .../qa/438/screenshots/03-sync-error-state.png     |   Bin 0 -> 79897 bytes
 .../04-sync-failure-no-loading-state.png           |   Bin 0 -> 60658 bytes
 .../screenshots/05-connected-status-preserved.png  |   Bin 84035 -> 117858 bytes
 .../screenshots/06-unauthenticated-redirect.png    |   Bin 28408 -> 28414 bytes
 .../438/screenshots/s1-integrations-full-page.png  |   Bin 0 -> 107092 bytes
 .../qa/438/screenshots/s1-integrations-page.png    |   Bin 0 -> 81256 bytes
 .../screenshots/s2-sync-button-enabled-state.png   |   Bin 0 -> 42956 bytes
 .../qa/438/screenshots/s2-sync-button-enabled.png  |   Bin 0 -> 42956 bytes
 .../qa/438/screenshots/s3-after-sync-click.png     |   Bin 0 -> 44226 bytes
 .../qa/438/screenshots/s3-sync-flash-messages.png  |   Bin 0 -> 44226 bytes
 .../qa/438/screenshots/s3-sync-flash-state.png     |   Bin 0 -> 81130 bytes
 .../qa/438/screenshots/s4-post-sync-state.png      |   Bin 0 -> 82555 bytes
 .../screenshots/s5-connected-status-preserved.png  |   Bin 0 -> 44226 bytes
 .../screenshots/s6-unauthenticated-redirect.png    |   Bin 0 -> 28408 bytes
 .../qa/439/{result.md => result_complete.md}       |     0
 .code_my_spec/qa/441/result_complete.md            |   152 +
 ...{result.md => result_failed_20260316_193227.md} |     0
 .../qa/441/result_failed_20260316_194519.md        |   172 +
 .../screenshots/s1-unauthenticated-redirect.png    |   Bin 0 -> 28408 bytes
 .../qa/441/screenshots/s10-semantic-warning.png    |   Bin 0 -> 22679 bytes
 .../qa/441/screenshots/s2-dashboard-loaded.png     |   Bin 0 -> 44574 bytes
 .../441/screenshots/s2-dashboard-primary-route.png |   Bin 0 -> 44574 bytes
 .../qa/441/screenshots/s2-dashboards-id-route.png  |   Bin 0 -> 37830 bytes
 .../qa/441/screenshots/s3-onboarding-prompt.png    |   Bin 0 -> 37830 bytes
 .../qa/441/screenshots/s4-page-heading-2.png       |   Bin 0 -> 46304 bytes
 .../qa/441/screenshots/s4-page-heading.png         |   Bin 0 -> 46304 bytes
 .../qa/441/screenshots/s5-filter-controls-2.png    |   Bin 0 -> 46304 bytes
 .../qa/441/screenshots/s5-filter-controls.png      |   Bin 0 -> 28700 bytes
 .../qa/441/screenshots/s6-date-range-display.png   |   Bin 0 -> 46304 bytes
 .code_my_spec/qa/441/screenshots/s6-date-range.png |   Bin 0 -> 44574 bytes
 .../qa/441/screenshots/s7-after-filter-7days.png   |   Bin 0 -> 44867 bytes
 .../441/screenshots/s7-all-platforms-restored.png  |   Bin 0 -> 47692 bytes
 .../qa/441/screenshots/s7-before-filter-click.png  |   Bin 0 -> 44574 bytes
 .../screenshots/s7-platform-filter-facebook.png    |   Bin 0 -> 41617 bytes
 .../441/screenshots/s7-platform-filter-google.png  |   Bin 0 -> 38805 bytes
 .../qa/441/screenshots/s8-metrics-area-stats.png   |   Bin 0 -> 28833 bytes
 .code_my_spec/qa/443/brief.md                      |   163 +
 .code_my_spec/qa/443/result.md                     |   294 +
 .code_my_spec/qa/447/result.md                     |   221 +-
 .../qa/447/result_failed_20260316_210510.md        |   112 +
 .../qa/454/{result.md => result_complete.md}       |     0
 .code_my_spec/qa/455/result_complete.md            |   217 +
 ...{result.md => result_failed_20260316_002125.md} |     0
 .../qa/455/result_failed_20260316_003256.md        |   117 +
 .../qa/455/screenshots/00-accounts-list.png        |   Bin 0 -> 23777 bytes
 .../455/screenshots/01-scenario1-danger-zone.png   |   Bin 0 -> 32315 bytes
 .../qa/455/screenshots/01-settings-full-page.png   |   Bin 0 -> 138645 bytes
 .../02-member-role-changed-to-admin.png            |   Bin 0 -> 37435 bytes
 .../screenshots/02-scenario2-member-settings.png   |   Bin 0 -> 111244 bytes
 .../455/screenshots/03-scenario3-warning-text.png  |   Bin 0 -> 32315 bytes
 .../screenshots/04-scenario4-wrong-name-flash.png  |   Bin 0 -> 35559 bytes
 .../05-scenario5-wrong-password-flash.png          |   Bin 0 -> 34650 bytes
 .../06-scenario6-empty-password-flash.png          |   Bin 0 -> 34737 bytes
 .../screenshots/07-scenario7-after-deletion.png    |   Bin 0 -> 21692 bytes
 .../screenshots/07-scenario7-before-deletion.png   |   Bin 0 -> 141081 bytes
 .../455/screenshots/07-scenario7-dev-mailbox.png   |   Bin 0 -> 26747 bytes
 ...08-scenario8-member-accounts-after-deletion.png |   Bin 0 -> 29929 bytes
 .../09-scenario9-owner-settings-after-deletion.png |   Bin 0 -> 20915 bytes
 .../455/screenshots/scenario-01-settings-page.png  |   Bin 0 -> 134044 bytes
 .../screenshots/scenario-02-member-settings.png    |   Bin 0 -> 106560 bytes
 .../qa/455/screenshots/scenario-03-danger-zone.png |   Bin 0 -> 32315 bytes
 .../screenshots/scenario-04-wrong-name-flash.png   |   Bin 0 -> 35559 bytes
 .../scenario-05-wrong-password-flash.png           |   Bin 0 -> 34650 bytes
 .../scenario-06-empty-password-flash.png           |   Bin 0 -> 34737 bytes
 .../455/screenshots/scenario-07-after-deletion.png |   Bin 0 -> 20256 bytes
 .../screenshots/scenario-07-before-deletion.png    |   Bin 0 -> 134044 bytes
 .../qa/455/screenshots/scenario-07-mailbox.png     |   Bin 0 -> 26747 bytes
 .../scenario-08-member-accounts-after-deletion.png |   Bin 0 -> 29929 bytes
 .../scenario-09-owner-after-deletion.png           |   Bin 0 -> 20915 bytes
 .../qa/493/{result.md => result_complete.md}       |     0
 .../qa/495/{result.md => result_complete.md}       |     0
 .code_my_spec/qa/509/brief.md                      |   164 +
 .code_my_spec/qa/509/result_complete.md            |   145 +
 .../qa/509/result_failed_20260317_174421.md        |   174 +
 .../qa/509/result_failed_20260317_180627.md        |   178 +
 .../qa/509/screenshots/01-sync-history-page.png    |   Bin 0 -> 507600 bytes
 .../qa/509/screenshots/02-schedule-section.png     |   Bin 0 -> 49935 bytes
 .code_my_spec/qa/509/screenshots/03-date-range.png |   Bin 0 -> 49935 bytes
 .../509/screenshots/04-has-records-not-empty.png   |   Bin 0 -> 49935 bytes
 .../qa/509/screenshots/04-populated-state.png      |   Bin 0 -> 507600 bytes
 .../qa/509/screenshots/05-filter-failed-active.png |   Bin 0 -> 72278 bytes
 .../screenshots/06-unauthenticated-redirect.png    |   Bin 0 -> 28427 bytes
 .code_my_spec/qa/510/brief.md                      |   144 +
 .code_my_spec/qa/510/result_complete.md            |   100 +
 .../qa/510/screenshots/01-sync-history-page.png    |   Bin 0 -> 52864 bytes
 .../qa/510/screenshots/02-schedule-section.png     |   Bin 0 -> 50628 bytes
 .code_my_spec/qa/510/screenshots/03-date-range.png |   Bin 0 -> 50628 bytes
 .../qa/510/screenshots/04-filter-tabs.png          |   Bin 0 -> 50628 bytes
 .../qa/510/screenshots/05-sync-entries-present.png |   Bin 0 -> 50628 bytes
 .../510/screenshots/06-filter-success-active.png   |   Bin 0 -> 51947 bytes
 .../510/screenshots/07-connect-page-google-ads.png |   Bin 0 -> 36560 bytes
 .code_my_spec/qa/511/brief.md                      |   188 +
 .code_my_spec/qa/511/result_complete.md            |   142 +
 .../s1-sync-history-facebook-entries.png           |   Bin 0 -> 56133 bytes
 .../qa/511/screenshots/s1-sync-history-full.png    |   Bin 0 -> 424988 bytes
 .../qa/511/screenshots/s1-sync-history-page.png    |   Bin 0 -> 49827 bytes
 .../screenshots/s3-unauthenticated-redirect.png    |   Bin 0 -> 28408 bytes
 .../qa/511/screenshots/s4-connect-page.png         |   Bin 0 -> 36560 bytes
 .../qa/511/screenshots/s5-facebook-detail.png      |   Bin 0 -> 32083 bytes
 .../qa/511/screenshots/s7-before-filter.png        |   Bin 0 -> 49827 bytes
 .../qa/511/screenshots/s7-filter-failed.png        |   Bin 0 -> 72914 bytes
 .../qa/511/screenshots/s7-filter-success.png       |   Bin 0 -> 63564 bytes
 .../qa/511/screenshots/s9-integrations-index.png   |   Bin 0 -> 45203 bytes
 .code_my_spec/qa/513/brief.md                      |   114 +
 .code_my_spec/qa/513/result_complete.md            |    87 +
 .../qa/513/result_failed_20260318_005139.md        |    86 +
 .../513/screenshots/01-sync-history-page-load.png  |   Bin 0 -> 427922 bytes
 .../513/screenshots/02-empty-state-or-history.png  |   Bin 0 -> 53118 bytes
 .../qa/513/screenshots/03-filter-tabs.png          |   Bin 0 -> 59794 bytes
 .../qa/513/screenshots/05-persisted-entries.png    |   Bin 0 -> 427886 bytes
 .../qa/513/screenshots/06-failed-filter.png        |   Bin 0 -> 59794 bytes
 .code_my_spec/qa/516/brief.md                      |   167 +
 .code_my_spec/qa/516/result_complete.md            |   138 +
 .../qa/516/result_failed_20260317_185714.md        |   131 +
 .../qa/516/result_failed_20260317_191558.md        |   155 +
 .../qa/516/result_failed_20260317_192845.md        |   128 +
 .../qa/516/screenshots/02-page-loaded.png          |   Bin 0 -> 424988 bytes
 .../qa/516/screenshots/03-empty-state.png          |   Bin 0 -> 61199 bytes
 .../516/screenshots/03-history-entries-present.png |   Bin 0 -> 61075 bytes
 .../516/screenshots/03-sync-history-with-data.png  |   Bin 0 -> 59341 bytes
 .../qa/516/screenshots/04-filter-tabs-success.png  |   Bin 0 -> 61011 bytes
 .../qa/516/screenshots/04-filter-tabs.png          |   Bin 0 -> 59341 bytes
 .../qa/516/screenshots/05-spex-confirmed.png       |   Bin 0 -> 61044 bytes
 .../qa/516/screenshots/06-sync-history-final.png   |   Bin 0 -> 425018 bytes
 .code_my_spec/qa/517/brief.md                      |   127 +
 .code_my_spec/qa/517/result_complete.md            |   121 +
 .../qa/517/result_failed_20260317_230317.md        |   135 +
 .../qa/517/result_failed_20260317_231551.md        |   141 +
 .../qa/517/result_failed_20260317_232638.md        |   189 +
 .../517/screenshots/01-sync-history-page-load.png  |   Bin 0 -> 424988 bytes
 .../qa/517/screenshots/01-sync-history-page.png    |   Bin 0 -> 427827 bytes
 .../qa/517/screenshots/02-schedule-section.png     |   Bin 0 -> 52864 bytes
 .code_my_spec/qa/517/screenshots/03-date-range.png |   Bin 0 -> 52864 bytes
 .../517/screenshots/03-sync-history-with-data.png  |   Bin 0 -> 424988 bytes
 .../517/screenshots/04-filter-success-active.png   |   Bin 0 -> 63564 bytes
 .../517/screenshots/04-filter-tabs-all-active.png  |   Bin 0 -> 52864 bytes
 .../qa/517/screenshots/05-filter-failed-active.png |   Bin 0 -> 72914 bytes
 .../517/screenshots/05-filter-success-active.png   |   Bin 0 -> 63984 bytes
 .../qa/517/screenshots/06-filter-all-restored.png  |   Bin 0 -> 59341 bytes
 .../qa/517/screenshots/06-filter-failed-active.png |   Bin 0 -> 73358 bytes
 .../qa/517/screenshots/07-date-range-section.png   |   Bin 0 -> 59341 bytes
 .../qa/517/screenshots/07-filter-all-restored.png  |   Bin 0 -> 59775 bytes
 .../517/screenshots/08-sync-history-with-data.png  |   Bin 0 -> 427860 bytes
 .../517/screenshots/09-provider-names-verified.png |   Bin 0 -> 59775 bytes
 .../qa/517/screenshots/s2-sync-history-page.png    |   Bin 0 -> 49827 bytes
 .../qa/517/screenshots/s3-schedule-section.png     |   Bin 0 -> 49827 bytes
 .code_my_spec/qa/517/screenshots/s4-date-range.png |   Bin 0 -> 49827 bytes
 .../qa/517/screenshots/s5-filter-all-active.png    |   Bin 0 -> 49827 bytes
 .../517/screenshots/s5b-filter-success-active.png  |   Bin 0 -> 63564 bytes
 .../517/screenshots/s5c-filter-failed-active.png   |   Bin 0 -> 72914 bytes
 .../517/screenshots/s6-sync-history-with-data.png  |   Bin 0 -> 425018 bytes
 .code_my_spec/qa/plan.md                           |    25 +
 .../integrations/google_accounts.spec.md           |    56 +
 .../integration_live/connect.spec.md               |    52 +-
 .../metric_flow_web/integration_live/index.spec.md |    48 +-
 .../metric_flow_web/invitation_live/accept.spec.md |     1 -
 .../metric_flow_web/user_live/settings.spec.md     |    40 +-
 .code_my_spec/status/implementation_status.json    |     2 +-
 .code_my_spec/status/metric_flow.md                |     2 +-
 .code_my_spec/status/metric_flow/integrations.md   |    10 +
 .code_my_spec/status/metric_flow_web.md            |    23 +-
 .../status/metric_flow_web/account_live/index.md   |     2 +-
 .../status/metric_flow_web/account_live/members.md |     2 +-
 .../metric_flow_web/account_live/settings.md       |     2 +-
 .../status/metric_flow_web/active_account_hook.md  |     7 +-
 .../status/metric_flow_web/agency_live/settings.md |     2 +-
 .code_my_spec/status/metric_flow_web/ai_live.md    |    22 -
 .../status/metric_flow_web/ai_live/chat.md         |     2 +-
 .../status/metric_flow_web/ai_live/insights.md     |     2 +-
 .../status/metric_flow_web/core_components.md      |     7 +-
 .../status/metric_flow_web/correlation_live.md     |    11 -
 .../metric_flow_web/correlation_live/index.md      |     2 +-
 .../status/metric_flow_web/dashboard_live.md       |    22 -
 .../metric_flow_web/dashboard_live/editor.md       |     2 +-
 .../status/metric_flow_web/dashboard_live/show.md  |     2 +-
 .code_my_spec/status/metric_flow_web/error_html.md |     7 +-
 .code_my_spec/status/metric_flow_web/error_json.md |     7 +-
 .../status/metric_flow_web/health_controller.md    |     7 +-
 .../metric_flow_web/integration_live/index.md      |     2 +-
 .../integration_live/sync_history.md               |     2 +-
 .../integration_o_auth_controller.md               |     7 +-
 .../status/metric_flow_web/invitation_live.md      |     2 +-
 .../metric_flow_web/invitation_live/accept.md      |     2 +-
 .../status/metric_flow_web/invitation_live/send.md |     2 +-
 .code_my_spec/status/metric_flow_web/layouts.md    |     7 +-
 .../status/metric_flow_web/onboarding_live.md      |     7 +-
 .../status/metric_flow_web/page_controller.md      |     7 +-
 .code_my_spec/status/metric_flow_web/page_html.md  |     7 +-
 .code_my_spec/status/metric_flow_web/user_live.md  |     2 +-
 .../status/metric_flow_web/user_live/settings.md   |     2 +-
 .../metric_flow_web/user_session_controller.md     |     7 +-
 .../status/metric_flow_web/white_label_hook.md     |     7 +-
 .code_my_spec/status/project.md                    |     4 +-
 .code_my_spec/status/stories.md                    |   212 +-
 .code_my_spec/tasks/metric _f_low_fix_issues.md    |    54 -
 .../tasks/metric _f_low_fix_issues_problems.md     |     5 -
 .code_my_spec/tasks/metric _f_low_triage_issues.md |    29 +-
 .../tasks/metric _f_low_triage_issues_problems.md  |    11 +-
 .code_my_spec/tasks/metric _flow_fix_issues.md     |    64 +
 .../tasks/metric _flow_fix_issues_problems.md      |     5 +
 .code_my_spec/tasks/metric _flow_triage_issues.md  |    44 +
 .../tasks/metric _flow_triage_issues_problems.md   |    11 +
 .../auto_enrollment_rule_component_code.md         |    74 +
 ...auto_enrollment_rule_component_code_problems.md |    17 +
 .../integrations/google_accounts_component_spec.md |   143 +
 .../google_accounts_component_spec_problems.md     |     3 +
 .../integrations/integrations_component_test.md    |    60 +
 .../integrations_component_test_problems.md        |     2 +
 .../integrations_context_component_specs.md        |    16 +
 ...ntegrations_context_component_specs_problems.md |     2 +
 .code_my_spec/tasks/qa/story_435_qa_story.md       |   146 +
 .code_my_spec/tasks/qa/story_438_qa_story.md       |   146 +
 .code_my_spec/tasks/qa/story_443_qa_story.md       |   138 +
 .code_my_spec/tasks/qa/story_447_qa_story.md       |   146 +
 .code_my_spec/tasks/qa/story_518_qa_story.md       |   150 +
 .../444/subagent_prompts/bdd_specs_prompt.md       |   704 +
 .code_my_spec/tasks/stories/444/write_bdd_specs.md |    22 +
 .../509/subagent_prompts/bdd_specs_prompt.md       |   954 +
 .code_my_spec/tasks/stories/509/write_bdd_specs.md |    22 +
 .../510/subagent_prompts/bdd_specs_prompt.md       |   879 +
 .code_my_spec/tasks/stories/510/write_bdd_specs.md |    22 +
 .../511/subagent_prompts/bdd_specs_prompt.md       |   904 +
 .code_my_spec/tasks/stories/511/write_bdd_specs.md |    22 +
 .../513/subagent_prompts/bdd_specs_prompt.md       |   854 +
 .code_my_spec/tasks/stories/513/write_bdd_specs.md |    22 +
 .../516/subagent_prompts/bdd_specs_prompt.md       |   854 +
 .code_my_spec/tasks/stories/516/write_bdd_specs.md |    22 +
 .../517/subagent_prompts/bdd_specs_prompt.md       |   854 +
 .code_my_spec/tasks/stories/517/write_bdd_specs.md |    22 +
 .../518/subagent_prompts/bdd_specs_prompt.md       |   854 +
 .code_my_spec/tasks/stories/518/write_bdd_specs.md |    22 +
 .code_my_spec/tools/{ => issues}/accept-issue      |     0
 .code_my_spec/tools/{ => issues}/create-issue      |    13 +-
 .code_my_spec/tools/{ => issues}/dismiss-issue     |     4 +-
 .code_my_spec/tools/{ => issues}/get-issue         |     0
 .code_my_spec/tools/{ => issues}/list-issues       |     0
 .code_my_spec/tools/{ => issues}/resolve-issue     |     4 +-
 config/dev.exs                                     |     1 +
 config/runtime.exs                                 |     5 +
 config/test.exs                                    |     3 +-
 lib/metric_flow/accounts.ex                        |     1 +
 lib/metric_flow/accounts/account_repository.ex     |    17 +-
 lib/metric_flow/dashboards.ex                      |    19 +-
 lib/metric_flow/data_sync/sync_history.ex          |     2 +-
 lib/metric_flow/data_sync/sync_job.ex              |     2 +-
 lib/metric_flow/data_sync/sync_worker.ex           |    94 +-
 lib/metric_flow/integrations.ex                    |   126 +-
 lib/metric_flow/integrations/google_accounts.ex    |   100 +
 lib/metric_flow/integrations/o_auth_state_store.ex |    18 +-
 lib/metric_flow/integrations/providers/google.ex   |     2 +-
 .../integrations/providers/quick_books.ex          |    35 +-
 .../integrations/strategies/quickbooks_oauth2.ex   |    26 +
 lib/metric_flow/invitations/invitation_notifier.ex |     2 +-
 lib/metric_flow/metrics.ex                         |     2 +
 lib/metric_flow/metrics/metric_repository.ex       |    24 +
 lib/metric_flow/users/user_notifier.ex             |     9 +-
 lib/metric_flow_web/application.ex                 |    18 +-
 lib/metric_flow_web/components/layouts.ex          |     2 +
 .../components/layouts/root.html.heex              |     2 +-
 .../controllers/integration_oauth_controller.ex    |    45 +-
 .../controllers/user_session_controller.ex         |    11 +-
 lib/metric_flow_web/hooks/active_account_hook.ex   |    17 +-
 lib/metric_flow_web/live/account_live/index.ex     |    11 +-
 lib/metric_flow_web/live/account_live/members.ex   |    79 +-
 lib/metric_flow_web/live/account_live/settings.ex  |    62 +-
 lib/metric_flow_web/live/ai_live/chat.ex           |     2 +-
 lib/metric_flow_web/live/ai_live/insights.ex       |     2 +-
 lib/metric_flow_web/live/correlation_live/index.ex |     2 +-
 lib/metric_flow_web/live/dashboard_live/editor.ex  |    18 +-
 lib/metric_flow_web/live/dashboard_live/show.ex    |     7 +-
 .../live/integration_live/account_edit.ex          |     2 +-
 .../live/integration_live/connect.ex               |   538 +-
 lib/metric_flow_web/live/integration_live/index.ex |   301 +-
 .../live/integration_live/sync_history.ex          |     9 +-
 lib/metric_flow_web/live/invitation_live/accept.ex |     2 +-
 lib/metric_flow_web/live/invitation_live/send.ex   |     2 +-
 lib/metric_flow_web/live/onboarding_live.ex        |     2 +-
 lib/metric_flow_web/live/user_live/confirmation.ex |     2 +-
 lib/metric_flow_web/live/user_live/login.ex        |     2 +-
 lib/metric_flow_web/live/user_live/registration.ex |     2 +-
 lib/metric_flow_web/live/user_live/settings.ex     |     2 +-
 lib/metric_flow_web/user_auth.ex                   |    12 +-
 ...20260317155527_widen_metrics_string_columns.exs |    18 +
 priv/repo/qa_seed_436.exs                          |    31 +
 priv/repo/qa_seeds.exs                             |    98 +-
 test/cassettes/data_sync/ga4_fetch_metrics.json    |     2 +-
 test/cassettes/data_sync/ga4_unauthorized.json     |   101 +
 test/metric_flow/integrations_test.exs             |    61 +-
 .../invitations/invitation_notifier_test.exs       |     7 +-
 .../controllers/user_session_controller_test.exs   |    12 +-
 .../live/account_live/index_test.exs               |    17 +-
 .../live/account_live/members_test.exs             |    24 +-
 .../live/dashboard_live/editor_test.exs            |    36 +-
 .../live/integration_live/connect_test.exs         |     2 +-
 .../live/integration_live/index_test.exs           |   104 +-
 test/metric_flow_web/live/user_live/login_test.exs |     2 +-
 .../live/user_live/registration_test.exs           |     2 +-
 test/metric_flow_web/user_auth_test.exs            |     9 +-
 ...ogle_ads_facebook_ads_google_analytics_spex.exs |    39 +-
 ...r_new_tab_with_platform_authentication_spex.exs |    47 +-
 ..._redirected_back_to_platform_selection_spex.exs |    28 +-
 ...erties_to_sync_from_connected_platform_spex.exs |    46 +-
 ...counts_later_without_re-authenticating_spex.exs |    10 +-
 ...only_after_successful_oauth_completion_spex.exs |    10 +-
 ...ntegration_is_active_and_ready_to_sync_spex.exs |    10 +-
 ...uth_attempts_show_clear_error_messages_spex.exs |    12 +-
 ...ount_and_is_not_transferable_to_agency_spex.exs |     6 +-
 ...rm_name_connected_date_and_sync_status_spex.exs |     8 +-
 ...unts_are_selected_for_each_integration_spex.exs |     8 +-
 ...ted_accounts_without_re-authenticating_spex.exs |     6 +-
 ...an_disconnect_or_remove_an_integration_spex.exs |     4 +-
 ..._will_remain_but_no_new_data_will_sync_spex.exs |     6 +-
 ...ect_a_previously_disconnected_platform_spex.exs |    22 +-
 ...mediate_data_pull_for_that_integration_spex.exs |     8 +-
 ...ync_in_progress_with_loading_indicator_spex.exs |     4 +-
 ...sage_with_timestamp_and_records_synced_spex.exs |    10 +-
 ...sync_fails_error_details_are_displayed_spex.exs |     6 +-
 ...ere_with_automated_daily_sync_schedule_spex.exs |    20 +-
 ...ives_confirmation_email_after_deletion_spex.exs |     6 +-
 ...dpoint_not_the_universal_analytics_api_spex.exs |   120 +
 ...perty_selected_during_oauth_connection_spex.exs |   132 +
 ...ews_eventcount_keyevents_scrolledusers_spex.exs |   106 +
 ...yed_to_the_property_and_client_account_spex.exs |   124 +
 ..._day_after_the_last_stored_metric_date_spex.exs |   147 +
 ...nly_avoids_incomplete_current-day_data_spex.exs |    98 +
 ...and_stores_data_with_a_sampling_caveat_spex.exs |   122 +
 ...default_quota_10_requestssecondproject_spex.exs |   100 +
 ...lue_record_is_stored_rather_than_a_gap_spex.exs |   133 +
 ...a4_sessions_maps_to_canonical_sessions_spex.exs |    95 +
 ...s_labeled_google_analytics_metric_name_spex.exs |   115 +
 ...nd_surfaced_in_sync_status_and_history_spex.exs |   148 +
 ..._sourcemedium_are_stored_at_this_stage_spex.exs |   125 +
 ..._to_a_single-request_response_would_be_spex.exs |   119 +
 ..._limit_chunked_fetch_and_merge_by_date_spex.exs |   130 +
 ...the_customer_entity_with_date_segments_spex.exs |   114 +
 ...propertyid_configured_for_each_account_spex.exs |   141 +
 ...r_account_id_to_authenticate_api_calls_spex.exs |   120 +
 ...uest_no_separate_google_ads_oauth_flow_spex.exs |   115 +
 ...by_1000000_all_conversions_conversions_spex.exs |   106 +
 ...egmentation_one_row_per_day_per_metric_spex.exs |   112 +
 ...on_logic_before_correlation_can_be_run_spex.exs |   103 +
 ..._day_after_the_last_stored_metric_date_spex.exs |   175 +
 ...initial_delay_for_transient_api_errors_spex.exs |   126 +
 ...context_customerid_daterange_errorcode_spex.exs |   127 +
 ...nd_surfaced_in_sync_status_and_history_spex.exs |   151 +
 ..._values_are_in_standard_currency_units_spex.exs |   133 +
 ..._with_time_increment_1_daily_breakdown_spex.exs |   120 +
 ...cher_at_call_time_not_stored_in_config_spex.exs |   189 +
 ...facebook_app_secret_and_ads_read_scope_spex.exs |   152 +
 ...adset_or_ad_segmentation_at_this_stage_spex.exs |   145 +
 ..._cost_per_ad_click_cost_per_conversion_spex.exs |   106 +
 ...lete_registration_add_to_cart_checkout_spex.exs |   164 +
 ...ion_type_for_the_same_action_type_list_spex.exs |   125 +
 ...cted_and_stored_as_a_scalar_per_metric_spex.exs |   133 +
 ...ric_metric_values_are_skipped_silently_spex.exs |   148 +
 ..._day_after_the_last_stored_metric_date_spex.exs |   171 +
 ..._are_extracted_from_errorresponseerror_spex.exs |   142 +
 ...l_only_must_not_affect_production_sync_spex.exs |   144 +
 ...nd_surfaced_in_sync_status_and_history_spex.exs |   180 +
 ..._the_analytics_or_ads_client_libraries_spex.exs |   117 +
 ...ped_from_location_ids_before_api_calls_spex.exs |   151 +
 ...ys_retrieved_not_a_windowed_date_range_spex.exs |   132 +
 ...ields_rating_enum_converted_to_integer_spex.exs |   152 +
 ...einserting_data_lost_on_midway_failure_spex.exs |   180 +
 ...tal_reviews_and_average_rating_per_day_spex.exs |   130 +
 ...ntly_persisted_as_separate_metric_rows_spex.exs |   132 +
 ..._at_account_level_with_null_locationid_spex.exs |   165 +
 ..._for_that_location_fails_with_an_error_spex.exs |   131 +
 ...ut_googlebusinessaccountid_are_skipped_spex.exs |   140 +
 ...es_and_failures_is_returned_at_the_end_spex.exs |   187 +
 ...ogle_oauth_token_as_ga4_and_google_ads_spex.exs |    63 +
 ...stomers_without_a_site_url_are_skipped_spex.exs |    80 +
 ...dpoint_authenticated_via_google_oauth2_spex.exs |   120 +
 ..._the_customers_googlebusinessaccountid_spex.exs |   167 +
 ...0_metrics_fetched_as_daily_time_series_spex.exs |   106 +
 ...ow_per_metric_key_per_day_per_location_spex.exs |   123 +
 ...t_stored_metric_date_for_that_location_spex.exs |   180 +
 ...avoid_re-fetching_the_last_stored_date_spex.exs |   171 +
 ...null_or_missing_values_are_stored_as_0_spex.exs |   134 +
 ...ring_sync_to_generate_the_metric_label_spex.exs |   130 +
 ...rt_consistent_with_the_gsc_integration_spex.exs |   192 +
 ..._of_successes_and_failures_is_returned_spex.exs |   191 +
 ...h_different_platformservicetype_values_spex.exs |   222 +
 ..._oauth_story_435_no_separate_auth_flow_spex.exs |   116 +
 ...accounts_are_each_synced_independently_spex.exs |   150 +
 ...quickbooks_reports_or_transactions_api_spex.exs |   125 +
 ...rget_variable_for_correlation_analysis_spex.exs |   142 +
 ...s_can_optionally_be_correlated_as_well_spex.exs |   121 +
 ..._and_sum_of_debits_per_account_per_day_spex.exs |    97 +
 ...ts_and_quickbooks_account_daily_debits_spex.exs |   118 +
 ...financial_data_has_no_location_concept_spex.exs |    96 +
 ..._day_after_the_last_stored_metric_date_spex.exs |   150 +
 ...ontinuity_for_correlation_calculations_spex.exs |   156 +
 ...nd_surfaced_in_sync_status_and_history_spex.exs |   158 +
 test/support/shared_givens.ex                      |     2 +-
 690 files changed, 63332 insertions(+), 23175 deletions(-)
## c2f74ea - cmt

Date: 2026-03-15 10:53:25 -0400
Author: John Davenport


 .code_my_spec/architecture/overview.md             |     4 -
 .code_my_spec/config.yml                           |     2 +-
 .code_my_spec/framework/README.md                  |    64 +
 .code_my_spec/framework/bdd/spex.md                |   616 +
 .code_my_spec/framework/bdd/wallaby.md             |   667 +
 .code_my_spec/framework/boundary.md                |   366 +
 .code_my_spec/framework/conventions.md             |   615 +
 .code_my_spec/framework/devops/README.md           |    55 +
 .code_my_spec/framework/devops/aws-s3-iam.md       |   264 +
 .../framework/devops/cloudflare-dns-tunnels.md     |   338 +
 .../devops/cloudflare-resend-email-setup.md        |   185 +
 .../framework/devops/hetzner-docker-deploy.md      |   629 +
 .code_my_spec/framework/dotenvy.md                 |   255 +
 .code_my_spec/framework/heex/syntax.md             |   328 +
 .../framework/liveview/core_components.md          |   265 +
 .code_my_spec/framework/liveview/forms.md          |   313 +
 .code_my_spec/framework/liveview/patterns.md       |   347 +
 .code_my_spec/framework/liveview/testing.md        |   526 +
 .code_my_spec/framework/qa-tooling.md              |   439 +
 .../qa-tooling/authenticated_curl_example.sh       |    89 +
 .code_my_spec/framework/qa-tooling/curl.md         |   383 +
 .../framework/qa-tooling/vibium_reference.md       |   166 +
 .code_my_spec/framework/req/cassettes.md           |   376 +
 .code_my_spec/framework/req/clients.md             |   350 +
 .code_my_spec/framework/ui/daisyui.md              |   413 +
 .code_my_spec/framework/ui/tailwind.md             |   300 +
 .code_my_spec/framework/web-cli.md                 |   118 +
 .code_my_spec/internal/agent_test_events.json      | 42846 +++++++++++++++++++
 ...36-google_ads_integration_seed_cannot_be_run.md |    11 +-
 ...36-confirm_disconnect_button_labeled_confirm.md |     2 +-
 ...36-connect_button_initiates_oauth_instead_of.md |     2 +-
 ...36-disconnect_confirmation_uses_inline_panel.md |     2 +-
 ...36-disconnect_flash_message_missing_no_new_d.md |     2 +-
 .../spec/metric_flow/integrations.spec.md          |   196 +-
 .../integrations/o_auth_state_store.spec.md        |     7 +-
 .../integrations/providers/google.spec.md          |     3 +-
 .../integrations/providers/quick_books.spec.md     |   139 +-
 .../metric_flow_web/account_live/index.spec.md     |     1 -
 .../spec/metric_flow_web/ai_live/chat.spec.md      |     1 -
 .../spec/metric_flow_web/ai_live/insights.spec.md  |     1 -
 .../metric_flow_web/integration_live/index.spec.md |     1 -
 .../integration_live/sync_history.spec.md          |     1 -
 .code_my_spec/status/implementation_status.json    |     2 +-
 .code_my_spec/status/metric_flow.md                |    62 +-
 .code_my_spec/status/metric_flow/agencies.md       |     2 +-
 .code_my_spec/status/metric_flow/ai.md             |     2 +-
 .code_my_spec/status/metric_flow/correlations.md   |     2 +-
 .code_my_spec/status/metric_flow/dashboards.md     |     2 +-
 .code_my_spec/status/metric_flow/data_sync.md      |     2 +-
 .code_my_spec/status/metric_flow/integrations.md   |    42 +-
 .../status/metric_flow/integrations/integration.md |    11 +
 .../integrations/integration_repository.md         |    11 +
 .../metric_flow/integrations/o_auth_state_store.md |    53 +-
 .../status/metric_flow/integrations/providers.md   |    50 +
 .../metric_flow/integrations/providers/facebook.md |     2 +-
 .../metric_flow/integrations/providers/google.md   |    49 +-
 .code_my_spec/status/metric_flow/invitations.md    |     2 +-
 .code_my_spec/status/metric_flow/metrics.md        |     2 +-
 .code_my_spec/status/metric_flow_web.md            |    73 +-
 .../status/metric_flow_web/account_live.md         |     2 +-
 .../status/metric_flow_web/account_live/index.md   |    47 +-
 .../status/metric_flow_web/account_live/members.md |    47 +-
 .../metric_flow_web/account_live/settings.md       |    47 +-
 .../status/metric_flow_web/active_account_hook.md  |    50 +-
 .../status/metric_flow_web/agency_live.md          |     2 +-
 .../status/metric_flow_web/agency_live/settings.md |    47 +-
 .code_my_spec/status/metric_flow_web/ai_live.md    |    24 +-
 .../status/metric_flow_web/ai_live/chat.md         |    47 +-
 .../status/metric_flow_web/ai_live/insights.md     |    47 +-
 .../status/metric_flow_web/core_components.md      |    50 +-
 .../status/metric_flow_web/correlation_live.md     |    13 +-
 .../metric_flow_web/correlation_live/index.md      |    47 +-
 .../status/metric_flow_web/dashboard_live.md       |    24 +-
 .../metric_flow_web/dashboard_live/editor.md       |    47 +-
 .../status/metric_flow_web/dashboard_live/show.md  |    47 +-
 .code_my_spec/status/metric_flow_web/error_html.md |    50 +-
 .code_my_spec/status/metric_flow_web/error_json.md |    50 +-
 .../status/metric_flow_web/health_controller.md    |    50 +-
 .../status/metric_flow_web/integration_live.md     |     6 +-
 .../integration_live/account_edit.md               |    47 +-
 .../metric_flow_web/integration_live/connect.md    |    47 +-
 .../metric_flow_web/integration_live/index.md      |    47 +-
 .../integration_live/sync_history.md               |    47 +-
 .../integration_o_auth_controller.md               |    50 +-
 .../status/metric_flow_web/invitation_live.md      |     2 +-
 .../metric_flow_web/invitation_live/accept.md      |    47 +-
 .../status/metric_flow_web/invitation_live/send.md |    47 +-
 .code_my_spec/status/metric_flow_web/layouts.md    |    50 +-
 .../status/metric_flow_web/onboarding_live.md      |    50 +-
 .../status/metric_flow_web/page_controller.md      |    50 +-
 .code_my_spec/status/metric_flow_web/page_html.md  |    50 +-
 .../status/metric_flow_web/report_live.md          |     4 +-
 .../metric_flow_web/user_live/confirmation.md      |    47 +-
 .../status/metric_flow_web/user_live/login.md      |    47 +-
 .../metric_flow_web/user_live/registration.md      |    47 +-
 .../status/metric_flow_web/user_live/settings.md   |    47 +-
 .../metric_flow_web/user_session_controller.md     |    50 +-
 .../status/metric_flow_web/visualization_live.md   |     2 +-
 .../status/metric_flow_web/white_label_hook.md     |    50 +-
 .code_my_spec/status/project.md                    |     2 +-
 .code_my_spec/status/stories.md                    |    62 +-
 .code_my_spec/tasks/metric _f_low_fix_issues.md    |    54 +
 .../tasks/metric _f_low_fix_issues_problems.md     |     5 +
 .code_my_spec/tasks/metric _f_low_triage_issues.md |    32 +
 .../tasks/metric _f_low_triage_issues_problems.md  |     5 +
 .../accounts_component_code.md}                    |    12 +-
 .../accounts/accounts_component_code_problems.md   |     2 +
 .../tasks/metric_flow/ai/ai_component_test.md      |    62 -
 .../metric_flow/ai/ai_component_test_problems.md   |     2 -
 .../tasks/metric_flow/ai/ai_context_spec.md        |   185 -
 .../metric_flow/ai/ai_context_spec_problems.md     |     2 -
 .../metric_flow/ai/chat_message_component_spec.md  |   130 -
 .../ai/chat_message_component_spec_problems.md     |     2 -
 .../metric_flow/ai/chat_session_component_spec.md  |   130 -
 .../ai/chat_session_component_spec_problems.md     |     2 -
 .../tasks/metric_flow/ai/insight_component_spec.md |   130 -
 .../ai/insight_component_spec_problems.md          |     2 -
 .../ai/suggestion_feedback_component_spec.md       |   130 -
 .../suggestion_feedback_component_spec_problems.md |     2 -
 .../correlations/correlation_job_component_spec.md |   130 -
 .../correlation_job_component_spec_problems.md     |     2 -
 .../correlation_result_component_spec.md           |   130 -
 .../correlation_result_component_spec_problems.md  |     2 -
 .../correlations/correlations_component_test.md    |    62 -
 .../correlations_component_test_problems.md        |     2 -
 .../correlations/correlations_context_spec.md      |   185 -
 .../correlations_context_spec_problems.md          |     2 -
 .../correlations/math_component_test.md            |    62 -
 .../correlations/math_component_test_problems.md   |     2 -
 .../dashboards/dashboard_component_spec.md         |   130 -
 .../dashboard_component_spec_problems.md           |     2 -
 .../dashboard_visualization_component_spec.md      |   130 -
 ...hboard_visualization_component_spec_problems.md |     2 -
 .../dashboards/dashboards_component_test.md        |    62 -
 .../dashboards_component_test_problems.md          |     2 -
 .../dashboards/dashboards_context_spec.md          |   185 -
 .../dashboards/dashboards_context_spec_problems.md |     2 -
 .../dashboards/visualization_component_spec.md     |   130 -
 .../visualization_component_spec_problems.md       |     2 -
 .../integrations/facebook_component_spec.md        |   143 -
 .../facebook_component_spec_problems.md            |     3 -
 .../integrations/google_component_test.md          |    60 -
 .../integrations/google_component_test_problems.md |     2 -
 .../integrations_component_code_problems.md        |    18 -
 .../integrations_context_component_specs.md        |    16 -
 ...ntegrations_context_component_specs_problems.md |     4 -
 .../integrations_context_implementation.md         |    22 -
 ...integrations_context_implementation_problems.md |     2 -
 .../o_auth_state_store_component_code.md           |    74 -
 .../o_auth_state_store_component_code_problems.md  |     2 -
 .../o_auth_state_store_component_spec.md           |   143 -
 .../o_auth_state_store_component_spec_problems.md  |     3 -
 .../o_auth_state_store_component_test.md           |    62 -
 .../o_auth_state_store_component_test_problems.md  |     2 -
 .../integrations/quick_books_component_spec.md     |   143 -
 .../quick_books_component_spec_problems.md         |     3 -
 .../invitations/invitation_component_code.md       |    78 -
 .../invitation_component_code_problems.md          |    14 -
 .../invitations/invitation_component_spec.md       |   145 -
 .../invitation_component_spec_problems.md          |     2 -
 .../invitations/invitation_component_test.md       |    62 -
 .../invitation_component_test_problems.md          |     2 -
 .../invitation_notifier_component_spec.md          |   145 -
 .../invitation_notifier_component_spec_problems.md |     3 -
 .../invitation_notifier_component_test.md          |    62 -
 .../invitation_notifier_component_test_problems.md |     2 -
 .../invitation_repository_component_spec.md        |   145 -
 ...nvitation_repository_component_spec_problems.md |     2 -
 .../invitation_repository_component_test.md        |    62 -
 ...nvitation_repository_component_test_problems.md |     2 -
 .../invitations/invitations_component_code.md      |    78 -
 .../invitations_component_code_problems.md         |   189 -
 .../invitations/invitations_component_test.md      |    62 -
 .../invitations_component_test_problems.md         |     2 -
 .../invitations_context_component_specs.md         |    16 -
 ...invitations_context_component_specs_problems.md |     3 -
 .../invitations_context_design_review.md           |   138 -
 .../invitations_context_design_review_problems.md  |     3 -
 .../invitations_context_implementation.md          |    22 -
 .../invitations_context_implementation_problems.md |     4 -
 .../invitations/invitations_context_spec.md        |   185 -
 .../invitations_context_spec_problems.md           |     2 -
 .../ai_live/chat/chat_live_view_spec.md            |   208 -
 .../ai_live/chat/chat_live_view_spec_problems.md   |     2 -
 .../ai_live/insights/insights_live_view_spec.md    |   208 -
 .../insights/insights_live_view_spec_problems.md   |     2 -
 .../correlation_live/index/index_live_view_spec.md |   208 -
 .../index/index_live_view_spec_problems.md         |     2 -
 .../dashboard_live/editor/editor_component_code.md |   129 -
 .../editor/editor_component_code_problems.md       |     2 -
 .../dashboard_live/editor/editor_component_test.md |    64 -
 .../editor/editor_component_test_problems.md       |     2 -
 .../dashboard_live/editor/editor_live_view_spec.md |   208 -
 .../editor/editor_live_view_spec_problems.md       |     2 -
 ...ricflowweb_dashboardlive_show_live_view_spec.md |   208 -
 ...b_dashboardlive_show_live_view_spec_problems.md |     2 -
 .../dashboard_live/show/show_live_view_spec.md     |   208 -
 .../show/show_live_view_spec_problems.md           |     2 -
 .../connect/connect_component_code.md              |   129 -
 .../connect/connect_component_code_problems.md     |   117 -
 .../integration_live/index/index_component_code.md |   129 -
 .../index/index_component_code_problems.md         |    93 -
 ...b_integrationlive_synchistory_live_view_spec.md |   208 -
 ...tionlive_synchistory_live_view_spec_problems.md |     2 -
 .../accept/accept_component_code.md                |   129 -
 .../accept/accept_component_code_problems.md       |     2 -
 .../accept/accept_component_test.md                |    64 -
 .../accept/accept_component_test_problems.md       |     2 -
 .../accept/accept_live_view_spec.md                |   208 -
 .../accept/accept_live_view_spec_problems.md       |     2 -
 .../invitation_live/send/send_component_code.md    |   129 -
 .../send/send_component_code_problems.md           |     2 -
 .../invitation_live/send/send_component_test.md    |    64 -
 .../send/send_component_test_problems.md           |     2 -
 .../invitation_live/send/send_live_view_spec.md    |   208 -
 .../send/send_live_view_spec_problems.md           |     2 -
 .code_my_spec/tasks/qa/story_428_qa_story.md       |   147 -
 .code_my_spec/tasks/qa/story_429_qa_story.md       |   148 -
 .code_my_spec/tasks/qa/story_432_qa_story.md       |   138 -
 .code_my_spec/tasks/qa/story_433_qa_story.md       |   142 -
 .code_my_spec/tasks/qa/story_434_qa_story.md       |   148 -
 .code_my_spec/tasks/qa/story_435_qa_story.md       |   148 -
 .code_my_spec/tasks/qa/story_436_qa_story.md       |   148 -
 .code_my_spec/tasks/qa/story_437_qa_story.md       |   148 -
 .code_my_spec/tasks/qa/story_438_qa_story.md       |   148 -
 .../428/subagent_prompts/bdd_specs_prompt.md       |   697 -
 .code_my_spec/tasks/stories/428/write_bdd_specs.md |    22 -
 .../429/subagent_prompts/bdd_specs_prompt.md       |   666 -
 .code_my_spec/tasks/stories/429/write_bdd_specs.md |    22 -
 .../432/subagent_prompts/bdd_specs_prompt.md       |   679 -
 .code_my_spec/tasks/stories/432/write_bdd_specs.md |    22 -
 .../433/subagent_prompts/bdd_specs_prompt.md       |   803 -
 .code_my_spec/tasks/stories/433/write_bdd_specs.md |    22 -
 .../435/subagent_prompts/bdd_specs_prompt.md       |   741 -
 .code_my_spec/tasks/stories/435/write_bdd_specs.md |    22 -
 .../443/subagent_prompts/bdd_specs_prompt.md       |   741 -
 .code_my_spec/tasks/stories/443/write_bdd_specs.md |    22 -
 .code_my_spec/tools/accept-issue                   |    13 +
 .code_my_spec/tools/create-issue                   |    52 +
 .code_my_spec/tools/dismiss-issue                  |    15 +
 .code_my_spec/tools/get-issue                      |    12 +
 .code_my_spec/tools/list-issues                    |    32 +
 .code_my_spec/tools/login                          |    51 +
 .code_my_spec/tools/notify                         |    22 +
 .code_my_spec/tools/resolve-issue                  |    15 +
 .code_my_spec/tools/set-story-component            |    16 +
 .code_my_spec/tools/story-linkage                  |    12 +
 .gitignore                                         |     4 -
 config/test.exs                                    |     8 +-
 lib/metric_flow/integrations.ex                    |    46 +-
 lib/metric_flow/integrations/oauth_state_store.ex  |    60 -
 lib/metric_flow/integrations/providers/google.ex   |     9 +-
 .../integrations/providers/quick_books.ex          |    24 +-
 priv/repo/qa_seeds.exs                             |    34 +
 .../cassettes/oauth/quickbooks_revoke_success.json |    24 +
 .../oauth_quickbooks_revoke_bad_request.json       |    80 +
 .../oauth_quickbooks_revoke_network_error.json     |    80 +
 .../cassettes/oauth_quickbooks_revoke_success.json |    80 +
 .../integrations/o_auth_state_store_test.exs       |     8 +-
 .../integrations/providers/google_test.exs         |    36 +-
 .../integrations/providers/quick_books_test.exs    |    79 +-
 test/metric_flow/integrations_test.exs             |   496 +-
 262 files changed, 53093 insertions(+), 14878 deletions(-)
## c929a60 - Add OAuthStateStore implementation and test files for Facebook and QuickBooks providers

Date: 2026-03-15 01:00:31 -0400
Author: John Davenport


 lib/metric_flow/integrations/o_auth_state_store.ex |  77 ++++
 .../integrations/providers/facebook_test.exs       | 277 +++++++++++++
 .../integrations/providers/quick_books_test.exs    | 459 +++++++++++++++++++++
 3 files changed, 813 insertions(+)
## 0b60bb1 - just commit

Date: 2026-03-14 23:33:22 -0400
Author: John Davenport


 .code_my_spec/architecture/dependency_graph.mmd    |  25 -
 .code_my_spec/architecture/namespace_hierarchy.md  |  33 +-
 .code_my_spec/architecture/overview.md             | 111 ++--
 ...24-login_sh_csrf_token_url_encoding_breaks_o.md |  28 +
 ...25-post_users_log_in_with_email_only_body_re.md |   6 +-
 ...26-vibium_mcp_server_not_configured_browser_.md |  50 --
 ...29-bdd_spex_route_uses_invitations_token_acc.md |   4 +
 ...30-invite_form_defaults_to_owner_role_when_n.md |  23 +-
 ...30-phx_change_on_select_elements_does_not_fi.md |  31 -
 ...33-ownership_transfer_new_owner_cannot_see_t.md |   4 +
 ...29-invitations_table_migration_was_not_appli.md |  17 -
 ...29-screenshots_cannot_be_saved_to_project_di.md |  17 -
 ...32-qa_member_example_com_has_owner_role_on_q.md |  17 -
 ...36-confirm_disconnect_button_labeled_confirm.md |  21 +
 ...36-connect_button_initiates_oauth_instead_of.md |  21 +
 ...36-disconnect_confirmation_uses_inline_panel.md |  21 +
 ...36-disconnect_flash_message_missing_no_new_d.md |  21 +
 ...36-google_ads_integration_seed_cannot_be_run.md |  21 +
 ...38-sync_now_button_never_triggers_actual_dat.md |  21 +
 ...39-bdd_spex_reference_owner_with_integration.md |   4 +
 ...39-seed_script_fails_in_sandbox_due_to_cloud.md |   4 +
 ...50-b10_empty_filter_state_cannot_be_triggere.md |  17 -
 ...50-empty_state_test_for_insights_requires_an.md |  21 -
 ...0-empty_state_test_requires_isolated_user_ac.md |   4 +
 .code_my_spec/qa/436/result.md                     | 202 +++++++
 .../qa/436/screenshots/disconnect-cancelled.png    | Bin 0 -> 45426 bytes
 .../qa/436/screenshots/disconnect-modal.png        | Bin 0 -> 48106 bytes
 .../436/screenshots/integration-disconnected.png   | Bin 0 -> 45799 bytes
 .../436/screenshots/integration-platform-name.png  | Bin 0 -> 41113 bytes
 .../screenshots/integration-selected-accounts.png  | Bin 0 -> 84035 bytes
 .../qa/436/screenshots/integrations-index.png      | Bin 0 -> 41113 bytes
 .../qa/436/screenshots/reconnect-button.png        | Bin 0 -> 45799 bytes
 .code_my_spec/qa/438/result.md                     |  95 +++
 .../screenshots/01-integrations-page-initial.png   | Bin 0 -> 84035 bytes
 .../qa/438/screenshots/02-sync-button-enabled.png  | Bin 0 -> 42153 bytes
 .../qa/438/screenshots/03-sync-in-progress.png     | Bin 0 -> 42292 bytes
 .../screenshots/04-sync-stuck-syncing-state.png    | Bin 0 -> 84153 bytes
 .../438/screenshots/04b-sync-never-completes.png   | Bin 0 -> 84197 bytes
 .../screenshots/05-connected-status-preserved.png  | Bin 0 -> 84035 bytes
 .../screenshots/06-unauthenticated-redirect.png    | Bin 0 -> 28408 bytes
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../subagent_prompts/bdd_specs_story_456.md        | 664 ---------------------
 .../write_bdd_specs.md                             |  22 -
 .../subagent_prompts/bdd_specs_story_441.md        | 654 --------------------
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../subagent_prompts/bdd_specs_story_451.md        | 629 -------------------
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../subagent_prompts/bdd_specs_story_425.md        | 474 ---------------
 .../subagent_prompts/bdd_specs_story_426.md        | 530 ----------------
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../write_bdd_specs.md                             |  22 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../session.json                                   |   1 -
 .../integrations/o_auth_state_store.spec.md        |  66 ++
 .../integrations/providers/facebook.spec.md        |  85 +++
 .../integrations/providers/quick_books.spec.md     | 132 ++++
 .../spec/metric_flow_web/user_live/login.spec.md   |   1 -
 .code_my_spec/status/implementation_status.json    |   2 +-
 .code_my_spec/status/metric flow_fix_issues.md     | 179 ------
 .../status/metric flow_fix_issues_problems.md      |   9 -
 .code_my_spec/status/metric flow_triage_issues.md  | 177 ------
 .../status/metric flow_triage_issues_problems.md   |  10 -
 .code_my_spec/status/metric_flow.md                |  64 +-
 .code_my_spec/status/metric_flow/accounts.md       |   6 +-
 .code_my_spec/status/metric_flow/agencies.md       |   6 +-
 .../metric_flow/agencies/agencies_repository.md    |  11 -
 .../metric_flow/agencies/auto_enrollment_rule.md   |  11 -
 .../status/metric_flow/agencies/develop_context.md |  44 --
 ...w_agencies_agenciesrepository_component_spec.md | 118 ----
 ...w_agencies_agenciesrepository_component_test.md |  62 --
 ...s_agenciesrepository_component_test_problems.md |   2 -
 ...w_agencies_autoenrollmentrule_component_spec.md | 118 ----
 .../agencies/metricflow_agencies_component_test.md |  62 --
 .../metricflow_agencies_component_test_problems.md |   2 -
 .../agencies/metricflow_agencies_context_spec.md   | 146 -----
 ...low_agencies_whitelabelconfig_component_spec.md | 118 ----
 .../metric_flow/agencies/white_label_config.md     |  11 -
 .code_my_spec/status/metric_flow/ai.md             |   6 +-
 .../status/metric_flow/ai/chat_message.md          |   8 -
 .../status/metric_flow/ai/chat_session.md          |   8 -
 .../status/metric_flow/ai/develop_context.md       |  51 --
 .code_my_spec/status/metric_flow/ai/insight.md     |   8 -
 .../status/metric_flow/ai/insights_generator.md    |  11 -
 .code_my_spec/status/metric_flow/ai/llm_client.md  |  11 -
 .../ai/metricflow_ai_airepository_code.md          |  76 ---
 .../ai/metricflow_ai_airepository_test.md          |  64 --
 .../ai/metricflow_ai_chatmessage_code.md           |  88 ---
 .../ai/metricflow_ai_chatmessage_component_spec.md | 130 ----
 ...cflow_ai_chatmessage_component_spec_problems.md |   2 -
 .../ai/metricflow_ai_chatmessage_component_test.md |  62 --
 ...cflow_ai_chatmessage_component_test_problems.md |   2 -
 .../ai/metricflow_ai_chatsession_code.md           |  88 ---
 .../ai/metricflow_ai_chatsession_component_spec.md | 130 ----
 ...cflow_ai_chatsession_component_spec_problems.md |   2 -
 .../status/metric_flow/ai/metricflow_ai_code.md    |  76 ---
 .../metric_flow/ai/metricflow_ai_component_test.md |  62 --
 .../ai/metricflow_ai_component_test_problems.md    |   2 -
 .../metric_flow/ai/metricflow_ai_context_spec.md   | 185 ------
 .../ai/metricflow_ai_context_spec_problems.md      |   2 -
 .../metric_flow/ai/metricflow_ai_insight_code.md   |  88 ---
 .../ai/metricflow_ai_insight_component_spec.md     | 130 ----
 ...etricflow_ai_insight_component_spec_problems.md |   2 -
 .../ai/metricflow_ai_insightsgenerator_test.md     |  64 --
 .../metric_flow/ai/metricflow_ai_llmclient_code.md |  76 ---
 .../ai/metricflow_ai_reportgenerator_code.md       |  76 ---
 .../ai/metricflow_ai_reportgenerator_test.md       |  64 --
 .../ai/metricflow_ai_suggestionfeedback_code.md    |  88 ---
 ...ricflow_ai_suggestionfeedback_component_spec.md | 130 ----
 ...i_suggestionfeedback_component_spec_problems.md |   2 -
 .../status/metric_flow/ai/metricflow_ai_test.md    |  62 --
 .../status/metric_flow/ai/report_generator.md      |  11 -
 .../status/metric_flow/ai/suggestion_feedback.md   |   8 -
 .code_my_spec/status/metric_flow/application.md    |  13 -
 .code_my_spec/status/metric_flow/correlations.md   |   6 +-
 .../metric_flow/correlations/correlation_job.md    |   8 -
 .../metric_flow/correlations/correlation_result.md |   8 -
 .../metric_flow/correlations/correlation_worker.md |  11 -
 .../correlations/correlations_repository.md        |  11 -
 .../metric_flow/correlations/develop_context.md    |  54 --
 .../status/metric_flow/correlations/math.md        |  11 -
 .../correlations/metricflow_correlations_code.md   |  76 ---
 .../metricflow_correlations_component_test.md      |  62 --
 ...ricflow_correlations_component_test_problems.md |   2 -
 .../metricflow_correlations_context_spec.md        | 185 ------
 ...etricflow_correlations_context_spec_problems.md |   2 -
 .../metricflow_correlations_correlationjob_code.md |  88 ---
 ...tions_correlationjob_component_spec_problems.md |   2 -
 ...tricflow_correlations_correlationresult_code.md |  88 ---
 ...ns_correlationresult_component_spec_problems.md |   2 -
 ...low_correlations_correlationsrepository_code.md |  76 ---
 ...low_correlations_correlationsrepository_test.md |  64 --
 ...tricflow_correlations_correlationworker_code.md |  76 ---
 ...tricflow_correlations_correlationworker_test.md |  62 --
 .../metricflow_correlations_math_code.md           |  76 ---
 .../metricflow_correlations_math_component_test.md |  62 --
 ...ow_correlations_math_component_test_problems.md |   2 -
 .../metricflow_correlations_math_test.md           |  62 --
 .../correlations/metricflow_correlations_test.md   |  62 --
 .code_my_spec/status/metric_flow/dashboards.md     |   6 +-
 .../status/metric_flow/dashboards/dashboard.md     |   8 -
 .../dashboards/dashboard_visualization.md          |   8 -
 .../dashboards/dashboards_repository.md            |  11 -
 .../metricflow_dashboards_component_test.md        |  62 --
 ...etricflow_dashboards_component_test_problems.md |   2 -
 .../metricflow_dashboards_context_spec.md          | 185 ------
 .../metricflow_dashboards_context_spec_problems.md |   2 -
 ...tricflow_dashboards_dashboard_component_spec.md | 130 ----
 ...dashboards_dashboard_component_spec_problems.md |   2 -
 ...boards_dashboardvisualization_component_spec.md | 130 ----
 ...shboardvisualization_component_spec_problems.md |   2 -
 ...flow_dashboards_visualization_component_spec.md | 130 ----
 ...boards_visualization_component_spec_problems.md |   2 -
 .../status/metric_flow/dashboards/visualization.md |   8 -
 .../dashboards/visualizations_repository.md        |  11 -
 .code_my_spec/status/metric_flow/data_sync.md      |   8 +-
 .../data_sync/data_providers/behaviour.md          |  11 -
 .../data_sync/data_providers/facebook_ads.md       |  11 -
 .../data_sync/data_providers/google_ads.md         |  11 -
 .../data_sync/data_providers/google_analytics.md   |  11 -
 .../data_sync/data_providers/quick_books.md        |  11 -
 .../metric_flow/data_sync/develop_context.md       |  84 ---
 .../data_sync/metricflow_datasync_code.md          |  76 ---
 ...icflow_datasync_dataproviders_behaviour_code.md |  76 ---
 ...icflow_datasync_dataproviders_behaviour_test.md |  64 --
 ...flow_datasync_dataproviders_facebookads_code.md |  76 ---
 ...flow_datasync_dataproviders_facebookads_test.md |  64 --
 ...icflow_datasync_dataproviders_googleads_code.md |  76 ---
 ...icflow_datasync_dataproviders_googleads_test.md |  64 --
 ..._datasync_dataproviders_googleanalytics_code.md |  76 ---
 ..._datasync_dataproviders_googleanalytics_test.md |  64 --
 ...cflow_datasync_dataproviders_quickbooks_code.md |  76 ---
 ...cflow_datasync_dataproviders_quickbooks_test.md |  64 --
 .../metricflow_datasync_scheduler_code.md          |  76 ---
 .../metricflow_datasync_scheduler_test.md          |  64 --
 .../metricflow_datasync_synchistory_code.md        |  76 ---
 .../metricflow_datasync_synchistory_test.md        |  64 --
 ...tricflow_datasync_synchistoryrepository_code.md |  76 ---
 ...tricflow_datasync_synchistoryrepository_test.md |  64 --
 .../data_sync/metricflow_datasync_syncjob_code.md  |  76 ---
 .../data_sync/metricflow_datasync_syncjob_test.md  |  64 --
 .../metricflow_datasync_syncjobrepository_code.md  |  76 ---
 .../metricflow_datasync_syncjobrepository_test.md  |  64 --
 .../metricflow_datasync_syncworker_code.md         |  76 ---
 .../metricflow_datasync_syncworker_test.md         |  64 --
 .../data_sync/metricflow_datasync_test.md          |  64 --
 .../status/metric_flow/data_sync/scheduler.md      |  11 -
 .../status/metric_flow/data_sync/sync_history.md   |  11 -
 .../data_sync/sync_history_repository.md           |  11 -
 .../status/metric_flow/data_sync/sync_job.md       |  11 -
 .../metric_flow/data_sync/sync_job_repository.md   |  11 -
 .../status/metric_flow/data_sync/sync_worker.md    |  11 -
 .code_my_spec/status/metric_flow/infrastructure.md |  41 --
 .code_my_spec/status/metric_flow/integrations.md   |  48 +-
 .../metric_flow/integrations/o_auth_state_store.md |  53 ++
 .../metric_flow/integrations/providers/facebook.md |  53 ++
 .../metric_flow/integrations/providers/google.md   |  53 ++
 .../integrations/providers/quick_books.md          |  53 ++
 .code_my_spec/status/metric_flow/invitations.md    |   6 +-
 .../metric_flow/{encrypted/binary.md => mailer.md} |   4 +-
 .code_my_spec/status/metric_flow/metrics.md        |   6 +-
 .../dev.md => metric_flow/repo.md}                 |  10 +-
 .../status/metric_flow/user_preferences.md         |  21 -
 .code_my_spec/status/metric_flow/users.md          |   6 +-
 .code_my_spec/status/metric_flow_web.md            |  76 ++-
 .../status/metric_flow_web/account_live.md         |   6 +-
 .../status/metric_flow_web/account_live/index.md   |  55 +-
 ...tricflowweb_accountlive_index_live_view_spec.md | 208 -------
 ...eb_accountlive_index_live_view_spec_problems.md |   2 -
 .../status/metric_flow_web/account_live/members.md |  51 +-
 .../metric_flow_web/account_live/settings.md       |  51 +-
 .../status/metric_flow_web/active_account_hook.md  |  50 +-
 .../status/metric_flow_web/agency_live.md          |   2 +-
 .../status/metric_flow_web/agency_live/clients.md  |  10 -
 .../status/metric_flow_web/agency_live/settings.md |  57 +-
 ...icflowweb_agencylive_settings_live_view_spec.md | 208 -------
 ..._agencylive_settings_live_view_spec_problems.md |   2 -
 .../status/metric_flow_web/agency_live/team.md     |  10 -
 .code_my_spec/status/metric_flow_web/ai_live.md    |  24 +-
 .../status/metric_flow_web/ai_live/chat.md         |  57 +-
 .../ai_live/chat/develop_live_view.md              |  47 --
 .../ai_live/chat/metricflowweb_ailive_chat_code.md | 146 -----
 .../metricflowweb_ailive_chat_component_code.md    | 129 ----
 ...cflowweb_ailive_chat_component_code_problems.md |  41 --
 .../metricflowweb_ailive_chat_live_view_spec.md    | 208 -------
 ...cflowweb_ailive_chat_live_view_spec_problems.md |   2 -
 .../ai_live/chat/metricflowweb_ailive_chat_test.md |  64 --
 .../status/metric_flow_web/ai_live/insights.md     |  57 +-
 .../metric_flow_web/ai_live/report_generator.md    |  11 -
 .../status/metric_flow_web/core_components.md      |  50 +-
 .../status/metric_flow_web/correlation_live.md     |  13 +-
 .../metric_flow_web/correlation_live/goals.md      |  11 -
 .../metric_flow_web/correlation_live/index.md      |  57 +-
 ...flowweb_correlationlive_index_live_view_spec.md | 208 -------
 ...orrelationlive_index_live_view_spec_problems.md |   2 -
 .../status/metric_flow_web/dashboard_live.md       |  24 +-
 .../metric_flow_web/dashboard_live/editor.md       |  57 +-
 .../status/metric_flow_web/dashboard_live/index.md |  11 -
 .../status/metric_flow_web/dashboard_live/show.md  |  57 +-
 ...ricflowweb_dashboardlive_show_live_view_spec.md | 208 -------
 ...b_dashboardlive_show_live_view_spec_problems.md |   2 -
 .code_my_spec/status/metric_flow_web/endpoint.md   |   8 +-
 .code_my_spec/status/metric_flow_web/error_html.md |  50 +-
 .code_my_spec/status/metric_flow_web/error_json.md |  50 +-
 .code_my_spec/status/metric_flow_web/gettext.md    |   8 +-
 .../status/metric_flow_web/health_controller.md    |  50 +-
 .../integration_callback_controller.md             |  11 -
 .../status/metric_flow_web/integration_live.md     |  10 +-
 .../integration_live/account_edit.md               |  53 ++
 .../metric_flow_web/integration_live/connect.md    |  51 +-
 .../metric_flow_web/integration_live/index.md      |  55 +-
 ...flowweb_integrationlive_index_live_view_spec.md | 208 -------
 ...ntegrationlive_index_live_view_spec_problems.md |   2 -
 .../integration_live/sync_history.md               |  57 +-
 ...b_integrationlive_synchistory_live_view_spec.md | 208 -------
 ...tionlive_synchistory_live_view_spec_problems.md |   2 -
 .../integration_o_auth_controller.md               |  50 +-
 .../status/metric_flow_web/invitation_live.md      |   4 +-
 .../metric_flow_web/invitation_live/accept.md      |  57 +-
 .../status/metric_flow_web/invitation_live/send.md |  57 +-
 .code_my_spec/status/metric_flow_web/layouts.md    |  50 +-
 .../status/metric_flow_web/onboarding_live.md      |  50 +-
 .../status/metric_flow_web/page_controller.md      |  50 +-
 .code_my_spec/status/metric_flow_web/page_html.md  |  50 +-
 .../status/metric_flow_web/report_live.md          |   4 +-
 .code_my_spec/status/metric_flow_web/router.md     |   8 +-
 .code_my_spec/status/metric_flow_web/telemetry.md  |   8 +-
 .code_my_spec/status/metric_flow_web/user_live.md  |   6 +-
 .../metric_flow_web/user_live/confirmation.md      |  50 +-
 .../status/metric_flow_web/user_live/login.md      |  53 +-
 .../metricflowweb_userlive_login_live_view_spec.md | 208 -------
 ...owweb_userlive_login_live_view_spec_problems.md |   2 -
 .../metric_flow_web/user_live/registration.md      |  51 +-
 .../status/metric_flow_web/user_live/settings.md   |  51 +-
 ...tricflowweb_userlive_settings_live_view_spec.md | 208 -------
 ...eb_userlive_settings_live_view_spec_problems.md |   2 -
 .../metric_flow_web/user_session_controller.md     |  50 +-
 .../status/metric_flow_web/visualization_live.md   |   2 +-
 .../metric_flow_web/visualization_live/editor.md   |  11 -
 .../status/metric_flow_web/white_label_hook.md     |  50 +-
 .code_my_spec/status/project.md                    |   2 +-
 .code_my_spec/status/qa/story_424_qa_story.md      | 148 -----
 .code_my_spec/status/qa/story_425_qa_story.md      | 148 -----
 .code_my_spec/status/qa/story_426_qa_story.md      | 148 -----
 .code_my_spec/status/qa/story_427_qa_story.md      | 143 -----
 .code_my_spec/status/qa/story_430_qa_story.md      | 145 -----
 .code_my_spec/status/qa/story_431_qa_story.md      | 149 -----
 .code_my_spec/status/qa/story_437_qa_story.md      | 149 -----
 .code_my_spec/status/qa/story_438_qa_story.md      | 143 -----
 .code_my_spec/status/qa/story_439_qa_story.md      | 143 -----
 .code_my_spec/status/qa/story_441_qa_story.md      | 147 -----
 .code_my_spec/status/qa/story_447_qa_story.md      | 145 -----
 .code_my_spec/status/qa/story_450_qa_story.md      | 148 -----
 .code_my_spec/status/qa/story_451_qa_story.md      | 145 -----
 .code_my_spec/status/qa/story_453_qa_story.md      | 147 -----
 .code_my_spec/status/qa/story_493_qa_story.md      | 149 -----
 .code_my_spec/status/qa/story_495_qa_story.md      | 147 -----
 .code_my_spec/status/stories.md                    | 112 ++--
 .../integrations/facebook_component_spec.md}       |  81 +--
 .../facebook_component_spec_problems.md            |   3 +
 .../integrations/google_component_test.md          |   2 -
 ...ntegrations_context_component_specs_problems.md |   2 +
 .../integrations_context_implementation.md         |  22 +
 ...integrations_context_implementation_problems.md |   2 +
 .../o_auth_state_store_component_code.md}          |  12 +-
 .../o_auth_state_store_component_code_problems.md  |   2 +
 .../o_auth_state_store_component_spec.md}          |  81 +--
 .../o_auth_state_store_component_spec_problems.md  |   3 +
 .../o_auth_state_store_component_test.md}          |   8 +-
 .../o_auth_state_store_component_test_problems.md  |   2 +
 .../integrations/quick_books_component_spec.md     |   2 -
 .../{status => tasks}/qa/story_434_qa_story.md     |   0
 .../{status => tasks}/qa/story_436_qa_story.md     |   2 +-
 .../qa/story_437_qa_story.md}                      |  26 +-
 .../qa/story_438_qa_story.md}                      |  26 +-
 .gitignore                                         |   1 +
 MetricFlow-Google-Ads-API-Design-Document.pdf      | Bin 0 -> 316128 bytes
 lib/metric_flow/integrations/providers/google.ex   |   9 +-
 lib/metric_flow_web/live/invitation_live/send.ex   |  12 +-
 lib/metric_flow_web/live/user_live/registration.ex |   2 +-
 mix.exs                                            |   3 +-
 .../integrations/o_auth_state_store_test.exs       |  92 +++
 .../integrations/providers/google_test.exs         |  36 +-
 .../live/correlation_live/index_test.exs           |   1 -
 uat.env                                            |  30 +
 366 files changed, 3061 insertions(+), 15530 deletions(-)
## 2462c8c - Fix all 29 test failures and eliminate compiler warnings

Date: 2026-03-11 22:33:47 -0400
Author: John Davenport


 .../dashboards/dashboards_repository.ex            |   5 +-
 lib/metric_flow_web/live/dashboard_live/editor.ex  |   4 +-
 lib/metric_flow_web/live/integration_live/index.ex | 323 ++++++++++++---------
 test/cassettes/ai/generate_vega_spec.json          |   2 +-
 .../data_sync/quickbooks_fetch_metrics.json        | 275 ++++++++++++++++++
 .../data_sync/quickbooks_unauthorized.json         |  59 ++++
 test/metric_flow/data_sync/sync_worker_test.exs    |   9 +-
 test/metric_flow/data_sync_test.exs                |   2 +-
 .../controllers/page_controller_test.exs           |   2 +-
 .../live/account_live/index_test.exs               |   4 +-
 .../live/account_live/settings_test.exs            |   2 +-
 test/metric_flow_web/live/ai_live/chat_test.exs    |  21 +-
 .../live/correlation_live/index_test.exs           |   2 +-
 .../live/integration_live/connect_test.exs         |   6 +-
 .../live/integration_live/sync_history_test.exs    |   2 +-
 .../live/invitation_live/accept_test.exs           |   2 +-
 .../live/invitation_live/send_test.exs             |   2 +-
 test/smoke_test.exs                                |   3 +-
 test/support/ai_stub.ex                            |  76 +++++
 19 files changed, 634 insertions(+), 167 deletions(-)
## 4937913 - Fix OAuth flows with cassette-based replay and update BDD specs

Date: 2026-03-11 22:13:07 -0400
Author: John Davenport


 .code_my_spec/architecture/dependency_graph.mmd    |   8 +-
 .code_my_spec/architecture/namespace_hierarchy.md  |   5 +-
 .code_my_spec/architecture/overview.md             |  18 ++
 ...34-brief_tests_google_analytics_platform_not.md |  21 ++
 ...34-google_ads_card_has_empty_description_whe.md |  21 ++
 ...34-oauth_callback_does_not_render_dedicated_.md |  30 +++
 ...34-per_platform_detail_view_uses_phx_click_b.md |  30 +++
 ...34-platform_list_does_not_include_google_ana.md |  30 +++
 .code_my_spec/qa/434/result.md                     | 229 ++++++++++++++++
 .../metric_flow_web/dashboard_live/editor.spec.md  |  63 ++++-
 .../spec/metric_flow_web/report_live/index.spec.md |  34 +++
 .../spec/metric_flow_web/report_live/show.spec.md  |  32 +++
 .code_my_spec/status/implementation_status.json    |   2 +-
 .code_my_spec/status/metric_flow.md                |  56 ++--
 .code_my_spec/status/metric_flow/encrypted.md      |   7 +-
 .code_my_spec/status/metric_flow_web.md            |  75 +++---
 .../status/metric_flow_web/account_live.md         |   7 +-
 .../status/metric_flow_web/agency_live.md          |   7 +-
 .code_my_spec/status/metric_flow_web/ai_live.md    |   7 +-
 .../status/metric_flow_web/correlation_live.md     |   7 +-
 .../status/metric_flow_web/dashboard_live.md       |  11 +-
 .../status/metric_flow_web/integration_live.md     |   7 +-
 .../status/metric_flow_web/invitation_live.md      |   7 +-
 .code_my_spec/status/metric_flow_web/plugs.md      |   7 +-
 .../status/metric_flow_web/report_live.md          |  32 +++
 .code_my_spec/status/metric_flow_web/user_live.md  |   7 +-
 .../status/metric_flow_web/visualization_live.md   |   7 +-
 .code_my_spec/status/project.md                    |   1 +
 .code_my_spec/status/stories.md                    | 138 ++++++++--
 lib/metric_flow/accounts.ex                        |   1 +
 lib/metric_flow/accounts/account_repository.ex     |  18 ++
 lib/metric_flow/accounts/authorization.ex          |   4 +
 lib/metric_flow/integrations.ex                    |  45 +---
 lib/metric_flow_web/live/account_live/settings.ex  |  49 ++++
 .../live/integration_live/connect.ex               |  67 ++---
 lib/metric_flow_web/live/integration_live/index.ex |  14 +-
 test/cassettes/ai/insights_generator_single.json   | 177 +++++++++++++
 test/cassettes/oauth/facebook_ads_callback.json    |  51 ++++
 test/cassettes/oauth/google_ads_callback.json      |  55 ++++
 test/cassettes/oauth/quickbooks_callback.json      |  30 +++
 ...-accepted_invitations_cannot_be_reused_spex.exs |   2 +-
 ..._redirected_back_to_platform_selection_spex.exs |  41 ++-
 ...erties_to_sync_from_connected_platform_spex.exs |  12 +-
 ...only_after_successful_oauth_completion_spex.exs |  11 +-
 ...ntegration_is_active_and_ready_to_sync_spex.exs |  27 +-
 ...uth_attempts_show_clear_error_messages_spex.exs |  48 ++--
 ...er_and_grants_access_to_financial_data_spex.exs |  41 +--
 ...only_after_successful_oauth_completion_spex.exs |  29 +-
 ...ckbooks_is_connected_and_ready_to_sync_spex.exs |  34 +--
 ...uth_attempts_show_clear_error_messages_spex.exs |  81 +++---
 ...r_metric_in_the_system_for_correlation_spex.exs |  10 +-
 ...ted_accounts_without_re-authenticating_spex.exs |   2 +-
 ...an_disconnect_or_remove_an_integration_spex.exs |   6 +-
 ..._will_remain_but_no_new_data_will_sync_spex.exs |   6 +-
 ...ect_a_previously_disconnected_platform_spex.exs |  18 +-
 ...w_report_from_template_or_blank_canvas_spex.exs |  17 +-
 test/support/oauth_stub.ex                         | 295 +++++++++++++++++++++
 test/support/shared_givens.ex                      | 106 ++++++++
 58 files changed, 1814 insertions(+), 389 deletions(-)
## 73d2aac - Add OAuth token revocation on disconnect and clear stale QA results

Date: 2026-03-11 16:34:48 -0400
Author: John Davenport


 .code_my_spec/qa/434/result.md                     | 268 ---------------------
 .code_my_spec/qa/435/result.md                     | 243 -------------------
 .code_my_spec/qa/436/result.md                     | 201 ----------------
 .code_my_spec/qa/437/result.md                     | 150 ------------
 .code_my_spec/qa/438/result.md                     | 113 ---------
 .code_my_spec/status/metric_flow.md                |  12 +-
 .code_my_spec/status/metric_flow_web.md            |  12 +-
 .code_my_spec/status/stories.md                    |  12 +-
 lib/metric_flow/integrations.ex                    |  26 ++
 .../integrations/providers/behaviour.ex            |  11 +
 .../integrations/providers/quick_books.ex          |  36 +++
 lib/metric_flow_web/live/integration_live/index.ex |   2 +-
 12 files changed, 92 insertions(+), 994 deletions(-)
## 4435a19 - Fix OAuth integration flows for Google, Facebook, and QuickBooks

Date: 2026-03-11 16:26:24 -0400
Author: John Davenport


 .code_my_spec/architecture/namespace_hierarchy.md  |   7 +-
 .code_my_spec/architecture/overview.md             |   2 +-
 ...28-accepted_invitation_link_is_not_invalidat.md |  30 +
 ...28-cancelled_and_invalid_invitation_tokens_r.md |  30 +
 ...28-validation_errors_shown_on_invitation_for.md |  31 +
 ...32-return_to_parameter_not_honored_after_pas.md |  33 +
 ...32-revoke_own_access_feature_is_not_implemen.md |  36 +
 ...33-settings_liveview_always_shows_the_most_r.md |  47 ++
 ...35-google_ads_card_shows_connected_but_conne.md |  26 +
 ...35-quickbooks_is_absent_from_the_integration.md |  26 +
 ...35-quickbooks_oauth_success_path_not_impleme.md |  28 +
 ...35-quickbooks_display_name_uses_incorrect_ca.md |  17 +
 ...35-seed_script_fails_when_run_via_mix_run_du.md |  17 +
 ...32-qa_member_example_com_has_owner_role_on_q.md |  17 +
 ...33-ownership_transfer_new_owner_cannot_see_t.md |  17 +
 .code_my_spec/qa/428/brief.md                      | 235 ++++++
 .code_my_spec/qa/428/result.md                     | 237 ++++++
 .../screenshots/01-invitations-page-initial.png    | Bin 0 -> 32924 bytes
 .../02-form-validation-errors-on-load.png          | Bin 0 -> 64739 bytes
 .../03-invitation-sent-external-email.png          | Bin 0 -> 35567 bytes
 .../04-invitation-sent-existing-user.png           | Bin 0 -> 35043 bytes
 .../qa/428/screenshots/05-dev-mailbox.png          | Bin 0 -> 47599 bytes
 .../screenshots/06-invitation-email-content.png    | Bin 0 -> 81390 bytes
 .../screenshots/07-invitation-acceptance-page.png  | Bin 0 -> 24958 bytes
 .../08-invitation-accepted-redirect.png            | Bin 0 -> 23920 bytes
 .../qa/428/screenshots/09-accepted-link-reused.png | Bin 0 -> 24958 bytes
 .../10-accepted-link-second-attempt.png            | Bin 0 -> 23920 bytes
 .../screenshots/11-pending-invitations-list.png    | Bin 0 -> 32924 bytes
 .../qa/428/screenshots/12-invitation-cancelled.png | Bin 0 -> 33524 bytes
 .../13-cancelled-invitation-redirect.png           | Bin 0 -> 76754 bytes
 .../14-multiple-invitations-pending.png            | Bin 0 -> 116657 bytes
 ...15-valid-pending-invitation-acceptance-page.png | Bin 0 -> 25571 bytes
 .../qa/428/screenshots/16-role-options-visible.png | Bin 0 -> 32924 bytes
 .../17-cancelled-link-no-flash-error.png           | Bin 0 -> 76754 bytes
 .../18-accepted-invitation-still-shows.png         | Bin 0 -> 24958 bytes
 .code_my_spec/qa/432/brief.md                      | 120 +++
 .code_my_spec/qa/432/result.md                     | 144 ++++
 .../qa/432/screenshots/01-dev-mailbox.png          | Bin 0 -> 116043 bytes
 .../432/screenshots/02-invitation-accept-page.png  | Bin 0 -> 50525 bytes
 .../432/screenshots/03-member-account-settings.png | Bin 0 -> 57495 bytes
 .../432/screenshots/04-owner-account-settings.png  | Bin 0 -> 109172 bytes
 .../05-owner-accounts-page-shows-admin-role.png    | Bin 0 -> 55343 bytes
 .../06-readonly-member-accounts-list.png           | Bin 0 -> 64883 bytes
 ...7-readonly-member-settings-no-revoke-button.png | Bin 0 -> 57495 bytes
 .code_my_spec/qa/433/brief.md                      | 163 ++++
 .code_my_spec/qa/433/result.md                     | 119 +++
 .../433/screenshots/member_no_transfer_section.png | Bin 0 -> 118800 bytes
 .../member_settings_default_account.png            | Bin 0 -> 118800 bytes
 .../qa/433/screenshots/new_owner_accounts_list.png | Bin 0 -> 202262 bytes
 .../new_owner_settings_wrong_account.png           | Bin 0 -> 118800 bytes
 .../qa/433/screenshots/owner_before_transfer.png   | Bin 0 -> 344391 bytes
 .../screenshots/owner_sees_transfer_section.png    | Bin 0 -> 344391 bytes
 .../qa/433/screenshots/owner_settings_page.png     | Bin 0 -> 107443 bytes
 .../433/screenshots/transfer_ownership_success.png | Bin 0 -> 250359 bytes
 .code_my_spec/qa/435/brief.md                      | 172 ++++
 .code_my_spec/qa/435/result.md                     | 243 ++++++
 .../qa/435/screenshots/explore-google-detail.png   | Bin 0 -> 30809 bytes
 .code_my_spec/qa/435/screenshots/login-page.png    | Bin 0 -> 25351 bytes
 .../screenshots/scenario-01-platform-selection.png | Bin 0 -> 34366 bytes
 .../screenshots/scenario-02-unsupported-flash.png  | Bin 0 -> 29739 bytes
 .../screenshots/scenario-03-facebook-connect.png   | Bin 0 -> 39654 bytes
 .../scenario-03-google-ads-reconnect.png           | Bin 0 -> 40325 bytes
 .../screenshots/scenario-04-google-ads-detail.png  | Bin 0 -> 31949 bytes
 .../screenshots/scenario-05-quickbooks-detail.png  | Bin 0 -> 31508 bytes
 .../screenshots/scenario-06-account-selection.png  | Bin 0 -> 34692 bytes
 .../scenario-07-save-redirects-integrations.png    | Bin 0 -> 41593 bytes
 .../435/screenshots/scenario-08-access-denied.png  | Bin 0 -> 29290 bytes
 .../435/screenshots/scenario-09-server-error.png   | Bin 0 -> 29908 bytes
 .../qa/435/screenshots/scenario-10-no-params.png   | Bin 0 -> 29889 bytes
 .../qa/435/screenshots/scenario-11-valid-code.png  | Bin 0 -> 28563 bytes
 .../screenshots/scenario-12-integrations-list.png  | Bin 0 -> 41593 bytes
 .../scenario-13-connect-page-no-quickbooks.png     | Bin 0 -> 34366 bytes
 .code_my_spec/qa/plan.md                           |  39 +-
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .code_my_spec/status/metric_flow.md                |  24 +-
 .code_my_spec/status/metric_flow/correlations.md   |   2 +-
 .../status/metric_flow/correlations/math.md        |  11 +
 .code_my_spec/status/metric_flow/dashboards.md     |   2 +-
 .code_my_spec/status/metric_flow/data_sync.md      |   6 +-
 .code_my_spec/status/metric_flow/integrations.md   |  36 +-
 .code_my_spec/status/metric_flow_web.md            |  22 +-
 .../status/metric_flow_web/dashboard_live.md       |   4 +-
 .../status/metric_flow_web/integration_live.md     |   6 +-
 .../integration_o_auth_controller.md               |  11 +
 .code_my_spec/status/stories.md                    |  32 +-
 .../integrations/google_component_test.md          |  62 ++
 .../integrations/google_component_test_problems.md |   2 +
 .../integrations/integrations_component_code.md    |  76 ++
 .../integrations_component_code_problems.md        |  18 +
 .../integrations_context_component_specs.md        |  16 +
 ...ntegrations_context_component_specs_problems.md |   2 +
 .../integrations/quick_books_component_spec.md     | 145 ++++
 .../quick_books_component_spec_problems.md         |   3 +
 .../dashboard_live/editor/editor_component_code.md | 129 +++
 .../editor/editor_component_code_problems.md       |   2 +
 .../dashboard_live/editor/editor_component_test.md |  64 ++
 .../editor/editor_component_test_problems.md       |   2 +
 .../dashboard_live/editor/editor_live_view_spec.md | 208 +++++
 .../editor/editor_live_view_spec_problems.md       |   2 +
 .../connect/connect_component_code.md              | 129 +++
 .../connect/connect_component_code_problems.md     | 117 +++
 .../integration_live/index/index_component_code.md | 129 +++
 .../index/index_component_code_problems.md         |  93 +++
 .code_my_spec/tasks/qa/story_432_qa_story.md       | 138 ++++
 .code_my_spec/tasks/qa/story_433_qa_story.md       | 142 ++++
 .code_my_spec/tasks/qa/story_435_qa_story.md       | 148 ++++
 .../432/subagent_prompts/bdd_specs_prompt.md       | 679 ++++++++++++++++
 .code_my_spec/tasks/stories/432/write_bdd_specs.md |  22 +
 .../433/subagent_prompts/bdd_specs_prompt.md       | 803 +++++++++++++++++++
 .code_my_spec/tasks/stories/433/write_bdd_specs.md |  22 +
 .../435/subagent_prompts/bdd_specs_prompt.md       | 741 ++++++++++++++++++
 .code_my_spec/tasks/stories/435/write_bdd_specs.md |  22 +
 .../443/subagent_prompts/bdd_specs_prompt.md       | 741 ++++++++++++++++++
 .code_my_spec/tasks/stories/443/write_bdd_specs.md |  22 +
 config/runtime.exs                                 |   6 +-
 lib/metric_flow/dashboards.ex                      |  35 +-
 lib/metric_flow/data_sync/sync_worker.ex           |  64 +-
 lib/metric_flow/integrations.ex                    |  69 +-
 lib/metric_flow/integrations/oauth_state_store.ex  |  60 ++
 lib/metric_flow/integrations/providers/facebook.ex |  67 ++
 lib/metric_flow/integrations/providers/google.ex   |   6 +-
 .../integrations/providers/quick_books.ex          | 112 +++
 lib/metric_flow_web/application.ex                 |   1 +
 .../controllers/integration_callback_controller.ex |  29 -
 .../controllers/integration_oauth_controller.ex    | 157 ++++
 lib/metric_flow_web/live/dashboard_live/editor.ex  | 526 +++++++++++++
 .../live/integration_live/connect.ex               | 219 +-----
 lib/metric_flow_web/live/integration_live/index.ex |  61 +-
 lib/metric_flow_web/router.ex                      |  10 +-
 priv/repo/qa_seeds_432.exs                         | 152 ++++
 test/cassettes/ai/generate_insights.json           | 177 +++++
 test/cassettes/ai/generate_vega_spec.json          | 166 ++++
 test/cassettes/ai/insights_generator_success.json  | 177 +++++
 test/cassettes/ai/report_generator_success.json    | 166 ++++
 .../integrations/providers/google_test.exs         |   4 +-
 .../live/dashboard_live/editor_test.exs            | 871 +++++++++++++++++++++
 .../live/integration_live/connect_test.exs         | 172 +---
 ...wn_access_from_client_account_settings_spex.exs | 134 ++++
 ..._owner_can_initiate_ownership_transfer_spex.exs |  72 ++
 ...can_initiate_oauth_flow_for_quickbooks_spex.exs |  61 ++
 ...er_and_grants_access_to_financial_data_spex.exs |  63 ++
 ..._select_which_income_accounts_to_track_spex.exs |  72 ++
 ...nts_system_will_sum_debits_and_credits_spex.exs |  55 ++
 ...only_after_successful_oauth_completion_spex.exs |  72 ++
 ...ckbooks_is_connected_and_ready_to_sync_spex.exs |  66 ++
 ...uth_attempts_show_clear_error_messages_spex.exs | 104 +++
 ...r_metric_in_the_system_for_correlation_spex.exs |  65 ++
 ...w_report_from_template_or_blank_canvas_spex.exs | 144 ++++
 test/support/fixtures/metrics_fixtures.ex          |  55 ++
 151 files changed, 10402 insertions(+), 542 deletions(-)
## f744a56 - Add integrations, pages, deploy scripts, and test updates

Date: 2026-03-10 09:00:04 -0400
Author: John Davenport


 .../knowledge/google_ads_developer_token.md        | 119 ++++++++++++++++++
 .code_my_spec/status/metric_flow.md                |  10 +-
 .code_my_spec/status/metric_flow/data_sync.md      |   2 +-
 .code_my_spec/status/metric_flow/integrations.md   |   2 +-
 .code_my_spec/status/metric_flow_web.md            |   8 +-
 .../status/metric_flow_web/integration_live.md     |   2 +-
 .code_my_spec/status/stories.md                    |   6 +-
 config/test.exs                                    |   9 +-
 docker-compose.prod.yml                            |  63 ++++++++++
 docker-compose.yml                                 |   9 +-
 lib/metric_flow/ai.ex                              |   1 +
 lib/metric_flow/integrations.ex                    |  17 ++-
 lib/metric_flow/integrations/providers/google.ex   |   9 +-
 lib/metric_flow_web/components/layouts.ex          |   9 ++
 lib/metric_flow_web/controllers/page_controller.ex |   8 ++
 .../controllers/page_html/home.html.heex           |  10 ++
 .../controllers/page_html/privacy.html.heex        | 120 +++++++++++++++++++
 .../controllers/page_html/terms.html.heex          | 133 +++++++++++++++++++++
 lib/metric_flow_web/live/integration_live/index.ex |  14 +++
 lib/metric_flow_web/router.ex                      |   7 ++
 mix.exs                                            |   2 +-
 mix.lock                                           |   2 +-
 scripts/deploy                                     |  32 +++++
 .../data_sync/data_providers/quick_books_test.exs  |  61 ++++++++++
 .../integrations/providers/google_test.exs         |  21 +---
 test/metric_flow/integrations_test.exs             |  54 ++++++++-
 ...ecified_access_level_to_client_account_spex.exs |  18 +--
 ...dded_to_their_account_switcher_or_list_spex.exs |   2 +-
 ..._access_based_on_agency_team_structure_spex.exs |   5 +-
 29 files changed, 686 insertions(+), 69 deletions(-)
## 66084bd - Fix data provider API versions and add cassette integration tests

Date: 2026-03-10 08:56:56 -0400
Author: John Davenport


 config/runtime.exs                                 |   21 +-
 .../data_sync/data_providers/facebook_ads.ex       |    2 +-
 .../data_sync/data_providers/google_ads.ex         |   51 +-
 .../data_sync/data_providers/google_analytics.ex   |    2 +-
 .../data_sync/facebook_ads_fetch_metrics.json      |   94 +
 .../data_sync/facebook_ads_unauthorized.json       |   90 +
 test/cassettes/data_sync/ga4_fetch_metrics.json    |  974 ++++++
 test/cassettes/data_sync/ga4_unauthorized.json     |  106 +
 .../data_sync/google_ads_fetch_metrics.json        | 3673 ++++++++++++++++++++
 .../data_sync/google_ads_unauthorized.json         |   78 +
 .../data_sync/data_providers/facebook_ads_test.exs |   61 +
 .../data_sync/data_providers/google_ads_test.exs   |   62 +
 .../data_providers/google_analytics_test.exs       |   73 +-
 test/support/fixtures/cassette_fixtures.ex         |  142 +
 test/test_helper.exs                               |    5 +
 15 files changed, 5408 insertions(+), 26 deletions(-)
## d14e934 - Add CodeMySpec specs, QA artifacts, invitations, and project updates

Date: 2026-03-07 13:21:22 -0500
Author: John Davenport


 .code_my_spec/architecture/dependency_graph.mmd    |  14 +-
 .code_my_spec/architecture/namespace_hierarchy.md  |  38 +-
 .code_my_spec/architecture/overview.md             |  32 +-
 .code_my_spec/dev_story/prompts.md                 |  94 +++
 .code_my_spec/devops/README.md                     |  93 +++
 .code_my_spec/devops/cloudflare.md                 | 102 +++
 .code_my_spec/devops/hetzner-deploy.md             | 367 +++++++++++
 .code_my_spec/devops/services.md                   | 270 ++++++++
 ...41-no_top_level_dashboard_route_bdd_specs_re.md |  26 +
 ...41-platform_filter_active_state_broken_for_g.md |  26 +
 ...50-ac3_ac4_dashboard_does_not_render_ai_info.md |  37 ++
 ...50-b9_empty_state_scenario_is_not_testable_w.md |  29 +
 ...51-ai_info_button_on_dashboard_does_not_navi.md |  26 +
 ...51-share_chat_insights_ui_is_not_implemented.md |  26 +
 ...51-start_qa_sh_does_not_source_uat_env_ai_ke.md |  27 +
 ...54-agencylive_settings_component_is_not_rend.md |  28 +
 ...54-app_layout_does_not_render_agency_logo_or.md |  27 +
 ...54-whitelabel_plug_is_not_wired_into_the_bro.md |  24 +
 ...54-whitelabelhook_is_not_registered_in_live_.md |  24 +
 ...93-seed_script_fails_in_sandbox_cloudflaretu.md |  26 +
 ...95-bdd_spex_suite_cannot_run_owner_with_inte.md |  26 +
 ...51-ai_streaming_fails_in_qa_environment_the_.md |  17 +
 ...29-bdd_spex_route_uses_invitations_token_acc.md |  17 +
 ...29-invitations_table_migration_was_not_appli.md |  17 +
 ...29-screenshots_cannot_be_saved_to_project_di.md |  17 +
 ...39-bdd_spex_reference_owner_with_integration.md |  25 +
 ...39-seed_script_fails_in_sandbox_due_to_cloud.md |  23 +
 ...50-b10_empty_filter_state_cannot_be_triggere.md |  17 +
 ...50-empty_state_test_for_insights_requires_an.md |  21 +
 ...0-empty_state_test_requires_isolated_user_ac.md |  27 +
 .code_my_spec/qa/429/brief.md                      | 157 +++++
 .code_my_spec/qa/429/result.md                     | 208 ++++++
 .code_my_spec/qa/437/brief.md                      | 159 +++++
 .code_my_spec/qa/437/result.md                     | 150 +++++
 .code_my_spec/qa/437/screenshots/01_page_load.png  | Bin 0 -> 49134 bytes
 .../qa/437/screenshots/02_schedule_section.png     | Bin 0 -> 49134 bytes
 .../qa/437/screenshots/03_providers_coverage.png   | Bin 0 -> 49134 bytes
 .code_my_spec/qa/437/screenshots/04_date_range.png | Bin 0 -> 49134 bytes
 .../qa/437/screenshots/05_empty_state.png          | Bin 0 -> 49134 bytes
 .../qa/437/screenshots/06_filter_buttons.png       | Bin 0 -> 49134 bytes
 .../qa/437/screenshots/07_filter_toggle.png        | Bin 0 -> 62156 bytes
 .../screenshots/09_metrics_financial_mention.png   | Bin 0 -> 62156 bytes
 .code_my_spec/qa/437/screenshots/10_full_page.png  | Bin 0 -> 82242 bytes
 .code_my_spec/qa/439/brief.md                      | 208 ++++++
 .code_my_spec/qa/439/result.md                     | 204 ++++++
 .../qa/439/screenshots/00-full-page-overview.png   | Bin 0 -> 79149 bytes
 .../qa/439/screenshots/01-sync-schedule.png        | Bin 0 -> 49134 bytes
 .../qa/439/screenshots/02-empty-state.png          | Bin 0 -> 45966 bytes
 .../qa/439/screenshots/03-filter-controls.png      | Bin 0 -> 49134 bytes
 .code_my_spec/qa/439/screenshots/04-date-range.png | Bin 0 -> 49134 bytes
 .../qa/439/screenshots/05-unauth-redirect.png      | Bin 0 -> 29747 bytes
 .../qa/439/screenshots/06-success-entry.png        | Bin 0 -> 42905 bytes
 .../qa/439/screenshots/07-failed-entry.png         | Bin 0 -> 42905 bytes
 .../qa/439/screenshots/08-filter-failed.png        | Bin 0 -> 49881 bytes
 .../qa/439/screenshots/09-filter-success.png       | Bin 0 -> 53960 bytes
 .code_my_spec/qa/439/screenshots/10-filter-all.png | Bin 0 -> 58222 bytes
 .code_my_spec/qa/441/brief.md                      | 129 ++++
 .code_my_spec/qa/441/result.md                     | 193 ++++++
 .../screenshots/01_unauthenticated_redirect.png    | Bin 0 -> 29772 bytes
 .../441/screenshots/02_dashboard_route_check.png   | Bin 0 -> 49913 bytes
 .../441/screenshots/03_after_login_dashboard.png   | Bin 0 -> 96001 bytes
 .../qa/441/screenshots/04_dashboard_full_state.png | Bin 0 -> 96001 bytes
 .../qa/441/screenshots/05_filter_controls.png      | Bin 0 -> 39359 bytes
 .../qa/441/screenshots/06_date_filter_7days.png    | Bin 0 -> 39596 bytes
 .../qa/441/screenshots/07_date_filter_all_time.png | Bin 0 -> 39770 bytes
 .../441/screenshots/08_platform_filter_google.png  | Bin 0 -> 41696 bytes
 .../qa/441/screenshots/09_ai_insights_panel.png    | Bin 0 -> 15873 bytes
 .../qa/441/screenshots/10_semantic_warning.png     | Bin 0 -> 97649 bytes
 .../qa/441/screenshots/11_onboarding_state.png     | Bin 0 -> 36727 bytes
 .../441/screenshots/12_custom_range_selected.png   | Bin 0 -> 41658 bytes
 .../qa/441/screenshots/13_dashboard_heading.png    | Bin 0 -> 41103 bytes
 .../qa/441/screenshots/14_platform_filter_bug.png  | Bin 0 -> 41103 bytes
 .code_my_spec/qa/447/brief.md                      | 207 ++++++
 .code_my_spec/qa/447/result.md                     | 112 ++++
 .code_my_spec/qa/450/brief.md                      | 230 +++++++
 .code_my_spec/qa/450/result.md                     | 193 ++++++
 .../450/screenshots/A1_correlations_raw_mode.png   | Bin 0 -> 191997 bytes
 .../450/screenshots/A1_correlations_smart_mode.png | Bin 0 -> 182061 bytes
 .../450/screenshots/A2_ai_suggestions_enabled.png  | Bin 0 -> 159915 bytes
 .../qa/450/screenshots/A3_feedback_buttons.png     | Bin 0 -> 172280 bytes
 .../screenshots/A3_feedback_helpful_confirmed.png  | Bin 0 -> 132871 bytes
 .../A4_feedback_not_helpful_confirmed.png          | Bin 0 -> 124111 bytes
 .../450/screenshots/B1_insights_page_initial.png   | Bin 0 -> 350848 bytes
 .../450/screenshots/B2_budget_increase_filter.png  | Bin 0 -> 157479 bytes
 .../qa/450/screenshots/B4_feedback_section.png     | Bin 0 -> 161244 bytes
 .../screenshots/B5_feedback_helpful_submitted.png  | Bin 0 -> 115522 bytes
 .../B6_feedback_not_helpful_submitted.png          | Bin 0 -> 114688 bytes
 .../qa/450/screenshots/B7_personalization_note.png | Bin 0 -> 103885 bytes
 .../screenshots/B8_feedback_persistence_reload.png | Bin 0 -> 351709 bytes
 .../qa/450/screenshots/B9_member_empty_state.png   | Bin 0 -> 166296 bytes
 .../450/screenshots/C1_ai_info_button_clicked.png  | Bin 0 -> 87168 bytes
 .../qa/450/screenshots/C1_ai_insights_panel.png    | Bin 0 -> 88014 bytes
 .code_my_spec/qa/450/screenshots/C1_dashboard.png  | Bin 0 -> 273544 bytes
 .../screenshots/insights_page_after_feedback.html  | 407 ++++++++++++
 .../qa/450/screenshots/insights_page_initial.html  | 404 ++++++++++++
 .../qa/450/screenshots/insights_page_member.html   | 417 ++++++++++++
 .code_my_spec/qa/451/brief.md                      | 122 ++++
 .code_my_spec/qa/451/result.md                     | 244 ++++++++
 .../qa/451/screenshots/b1-ai-info-button-click.png | Bin 0 -> 94189 bytes
 .code_my_spec/qa/451/screenshots/b1-dashboard.png  | Bin 0 -> 183139 bytes
 .../screenshots/b10-ai-error-second-message.png    | Bin 0 -> 169563 bytes
 .../screenshots/b10-metrics-question-submitted.png | Bin 0 -> 167154 bytes
 .../qa/451/screenshots/b14-history-after-nav.png   | Bin 0 -> 197492 bytes
 .../qa/451/screenshots/b14-session-loaded.png      | Bin 0 -> 172105 bytes
 .../qa/451/screenshots/b14-session-restored.png    | Bin 0 -> 172941 bytes
 .../qa/451/screenshots/b15-session-list-detail.png | Bin 0 -> 144147 bytes
 .../qa/451/screenshots/b17-member-chat-page.png    | Bin 0 -> 230612 bytes
 .../qa/451/screenshots/b2-correlations.png         | Bin 0 -> 193551 bytes
 .code_my_spec/qa/451/screenshots/b3-insights.png   | Bin 0 -> 164723 bytes
 .../qa/451/screenshots/b4-chat-direct.png          | Bin 0 -> 230058 bytes
 .../qa/451/screenshots/b4-no-session-selected.png  | Bin 0 -> 177790 bytes
 .../451/screenshots/b5-chat-context-indicator.png  | Bin 0 -> 210592 bytes
 .../qa/451/screenshots/b6-context-correlations.png | Bin 0 -> 208499 bytes
 .../qa/451/screenshots/b7-context-dashboard.png    | Bin 0 -> 227989 bytes
 .../qa/451/screenshots/b8-chat-input-visible.png   | Bin 0 -> 223442 bytes
 .../qa/451/screenshots/b9-after-submit-state.png   | Bin 0 -> 129958 bytes
 .../qa/451/screenshots/b9-ai-error-flash.png       | Bin 0 -> 193871 bytes
 .../451/screenshots/b9-revenue-question-typed.png  | Bin 0 -> 207882 bytes
 .../451/screenshots/b9-user-message-optimistic.png | Bin 0 -> 166008 bytes
 .code_my_spec/qa/453/brief.md                      | 173 +++++
 .code_my_spec/qa/453/result.md                     | 181 ++++++
 .../01_settings_page_white_label_section.html      | 375 +++++++++++
 .../02_settings_page_with_saved_config.html        | 389 ++++++++++++
 .code_my_spec/qa/454/brief.md                      | 130 ++++
 .code_my_spec/qa/454/result.md                     | 103 +++
 .../screenshots/accounts-settings-white-label.png  | Bin 0 -> 264225 bytes
 .../454/screenshots/dashboard-default-branding.png | Bin 0 -> 148374 bytes
 .../screenshots/dashboard-functionality-intact.png | Bin 0 -> 173773 bytes
 .../qa/454/screenshots/dashboard-main-domain.png   | Bin 0 -> 180314 bytes
 .../454/screenshots/dashboard-no-agency-colors.png | Bin 0 -> 171410 bytes
 .../454/screenshots/unauthenticated-redirect.png   | Bin 0 -> 155627 bytes
 .../454/screenshots/white-label-live-preview.png   | Bin 0 -> 236765 bytes
 .../qa/454/screenshots/white-label-reset.png       | Bin 0 -> 207338 bytes
 .code_my_spec/qa/493/brief.md                      | 148 +++++
 .code_my_spec/qa/493/result.md                     | 131 ++++
 .../qa/493/screenshots/01_dashboard_full.png       | Bin 0 -> 97530 bytes
 .code_my_spec/qa/493/screenshots/02_stat_cards.png | Bin 0 -> 40529 bytes
 .../qa/493/screenshots/03_platform_filter.png      | Bin 0 -> 40529 bytes
 .../screenshots/04_platform_specific_section.png   | Bin 0 -> 35668 bytes
 .../qa/493/screenshots/05_semantic_warning.png     | Bin 0 -> 35668 bytes
 .../screenshots/06_google_platform_filtered.png    | Bin 0 -> 40529 bytes
 .../qa/493/screenshots/07_integrations_page.png    | Bin 0 -> 33810 bytes
 .../493/screenshots/08_derived_metrics_cards.png   | Bin 0 -> 40529 bytes
 .../qa/493/screenshots/09_auth_guard_redirect.png  | Bin 0 -> 29747 bytes
 .code_my_spec/qa/495/brief.md                      | 165 +++++
 .code_my_spec/qa/495/result.md                     | 129 ++++
 .../qa/495/screenshots/01_dashboard_loads.png      | Bin 0 -> 97649 bytes
 .../qa/495/screenshots/02_onboarding_prompt.png    | Bin 0 -> 35811 bytes
 .../qa/495/screenshots/03_raw_metric_cards.png     | Bin 0 -> 41103 bytes
 .../qa/495/screenshots/04_derived_metric_cards.png | Bin 0 -> 41103 bytes
 .../qa/495/screenshots/05_no_badge_leakage.png     | Bin 0 -> 41103 bytes
 .../qa/495/screenshots/06_no_nan_infinity.png      | Bin 0 -> 41103 bytes
 .../qa/495/screenshots/07_date_range_filter.png    | Bin 0 -> 41522 bytes
 .../qa/495/screenshots/08_platform_filter.png      | Bin 0 -> 41465 bytes
 .../qa/495/screenshots/09_metric_type_filter.png   | Bin 0 -> 41252 bytes
 .../qa/495/screenshots/10_ai_insights_panel.png    | Bin 0 -> 45797 bytes
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../subagent_prompts/bdd_specs_story_456.md        | 664 ++++++++++++++++++++
 .../write_bdd_specs.md                             |  22 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .code_my_spec/spec/metric_flow/ai.spec.md          | 189 +++++-
 .../spec/metric_flow/ai/chat_message.spec.md       |  56 +-
 .../spec/metric_flow/ai/chat_session.spec.md       |  91 ++-
 .code_my_spec/spec/metric_flow/ai/insight.spec.md  | 123 +++-
 .../metric_flow/ai/suggestion_feedback.spec.md     |  84 ++-
 .../spec/metric_flow/correlations.spec.md          | 112 +++-
 .../correlations/correlation_job.spec.md           | 122 +++-
 .../correlations/correlation_result.spec.md        | 141 ++++-
 .code_my_spec/spec/metric_flow/dashboards.spec.md  | 183 +++++-
 .../spec/metric_flow/dashboards/dashboard.spec.md  |  77 ++-
 .../dashboards/dashboard_visualization.spec.md     |  61 +-
 .../metric_flow/dashboards/visualization.spec.md   |  70 ++-
 .code_my_spec/spec/metric_flow/invitations.spec.md | 155 ++++-
 .../spec/metric_flow/invitations/design_review.md  |  32 +
 .../metric_flow/invitations/invitation.spec.md     |  94 +++
 .../invitations/invitation_notifier.spec.md        |  38 ++
 .../invitations/invitation_repository.spec.md      | 121 ++++
 .../spec/metric_flow_web/ai_live/chat.spec.md      |  72 ++-
 .../spec/metric_flow_web/ai_live/insights.spec.md  |  76 ++-
 .../metric_flow_web/correlation_live/index.spec.md |  87 ++-
 .../metric_flow_web/dashboard_live/show.spec.md    |  61 +-
 .../integration_live/sync_history.spec.md          |  80 ++-
 .../metric_flow_web/invitation_live/accept.spec.md |  50 +-
 .../metric_flow_web/invitation_live/send.spec.md   |  74 ++-
 .code_my_spec/status/implementation_status.json    |   2 +-
 .code_my_spec/status/metric_flow.md                |  41 +-
 .code_my_spec/status/metric_flow/ai.md             |  12 +-
 .../ai/metricflow_ai_chatmessage_component_spec.md | 130 ++++
 ...cflow_ai_chatmessage_component_spec_problems.md |   2 +
 .../ai/metricflow_ai_chatmessage_component_test.md |  62 ++
 ...cflow_ai_chatmessage_component_test_problems.md |   2 +
 .../ai/metricflow_ai_chatsession_component_spec.md | 130 ++++
 ...cflow_ai_chatsession_component_spec_problems.md |   2 +
 .../metric_flow/ai/metricflow_ai_component_test.md |  62 ++
 .../ai/metricflow_ai_component_test_problems.md    |   2 +
 .../metric_flow/ai/metricflow_ai_context_spec.md   | 185 ++++++
 .../ai/metricflow_ai_context_spec_problems.md      |   2 +
 .../ai/metricflow_ai_insight_component_spec.md     | 130 ++++
 ...etricflow_ai_insight_component_spec_problems.md |   2 +
 ...ricflow_ai_suggestionfeedback_component_spec.md | 130 ++++
 ...i_suggestionfeedback_component_spec_problems.md |   2 +
 .code_my_spec/status/metric_flow/correlations.md   |   8 +-
 .../metricflow_correlations_component_test.md      |  62 ++
 ...ricflow_correlations_component_test_problems.md |   2 +
 .../metricflow_correlations_context_spec.md        | 185 ++++++
 ...etricflow_correlations_context_spec_problems.md |   2 +
 ...w_correlations_correlationjob_component_spec.md | 130 ++++
 ...tions_correlationjob_component_spec_problems.md |   2 +
 ...orrelations_correlationresult_component_spec.md | 130 ++++
 ...ns_correlationresult_component_spec_problems.md |   2 +
 .../metricflow_correlations_math_component_test.md |  62 ++
 ...ow_correlations_math_component_test_problems.md |   2 +
 .code_my_spec/status/metric_flow/dashboards.md     |   8 +-
 .../metricflow_dashboards_component_test.md        |  62 ++
 ...etricflow_dashboards_component_test_problems.md |   2 +
 .../metricflow_dashboards_context_spec.md          | 185 ++++++
 .../metricflow_dashboards_context_spec_problems.md |   2 +
 ...tricflow_dashboards_dashboard_component_spec.md | 130 ++++
 ...dashboards_dashboard_component_spec_problems.md |   2 +
 ...boards_dashboardvisualization_component_spec.md | 130 ++++
 ...shboardvisualization_component_spec_problems.md |   2 +
 ...flow_dashboards_visualization_component_spec.md | 130 ++++
 ...boards_visualization_component_spec_problems.md |   2 +
 .code_my_spec/status/metric_flow/invitations.md    |  40 +-
 .code_my_spec/status/metric_flow_web.md            |  46 +-
 .../status/metric_flow_web/active_account_hook.md  |  11 +
 .code_my_spec/status/metric_flow_web/ai_live.md    |  10 +-
 .../metricflowweb_ailive_chat_component_code.md    | 129 ++++
 ...cflowweb_ailive_chat_component_code_problems.md |  41 ++
 .../metricflowweb_ailive_chat_live_view_spec.md    | 208 ++++++
 ...cflowweb_ailive_chat_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/correlation_live.md     |   4 +-
 ...flowweb_correlationlive_index_live_view_spec.md | 208 ++++++
 ...orrelationlive_index_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/dashboard_live.md       |   8 +-
 ...ricflowweb_dashboardlive_show_live_view_spec.md | 208 ++++++
 ...b_dashboardlive_show_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/integration_live.md     |   2 +-
 .../status/metric_flow_web/invitation_live.md      |  16 +-
 ...tricflowweb_userlive_settings_live_view_spec.md | 208 ++++++
 ...eb_userlive_settings_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/visualization_live.md   |   2 +-
 .code_my_spec/status/project.md                    |   4 +-
 .code_my_spec/status/qa/story_437_qa_story.md      | 149 +++++
 .code_my_spec/status/qa/story_439_qa_story.md      | 143 +++++
 .code_my_spec/status/qa/story_441_qa_story.md      | 147 +++++
 .code_my_spec/status/qa/story_447_qa_story.md      | 145 +++++
 .code_my_spec/status/qa/story_450_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_451_qa_story.md      | 145 +++++
 .code_my_spec/status/qa/story_453_qa_story.md      | 147 +++++
 .code_my_spec/status/qa/story_454_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_493_qa_story.md      | 149 +++++
 .code_my_spec/status/qa/story_495_qa_story.md      | 147 +++++
 .code_my_spec/status/stories.md                    |  69 +-
 .../tasks/metric_flow/ai/ai_component_test.md      |  62 ++
 .../metric_flow/ai/ai_component_test_problems.md   |   2 +
 .../tasks/metric_flow/ai/ai_context_spec.md        | 185 ++++++
 .../metric_flow/ai/ai_context_spec_problems.md     |   2 +
 .../metric_flow/ai/chat_message_component_spec.md  | 130 ++++
 .../ai/chat_message_component_spec_problems.md     |   2 +
 .../metric_flow/ai/chat_session_component_spec.md  | 130 ++++
 .../ai/chat_session_component_spec_problems.md     |   2 +
 .../tasks/metric_flow/ai/insight_component_spec.md | 130 ++++
 .../ai/insight_component_spec_problems.md          |   2 +
 .../ai/suggestion_feedback_component_spec.md       | 130 ++++
 .../suggestion_feedback_component_spec_problems.md |   2 +
 .../correlations/correlation_job_component_spec.md | 130 ++++
 .../correlation_job_component_spec_problems.md     |   2 +
 .../correlation_result_component_spec.md           | 130 ++++
 .../correlation_result_component_spec_problems.md  |   2 +
 .../correlations/correlations_component_test.md    |  62 ++
 .../correlations_component_test_problems.md        |   2 +
 .../correlations/correlations_context_spec.md      | 185 ++++++
 .../correlations_context_spec_problems.md          |   2 +
 .../correlations/math_component_test.md            |  62 ++
 .../correlations/math_component_test_problems.md   |   2 +
 .../dashboards/dashboard_component_spec.md         | 130 ++++
 .../dashboard_component_spec_problems.md           |   2 +
 .../dashboard_visualization_component_spec.md      | 130 ++++
 ...hboard_visualization_component_spec_problems.md |   2 +
 .../dashboards/dashboards_component_test.md        |  62 ++
 .../dashboards_component_test_problems.md          |   2 +
 .../dashboards/dashboards_context_spec.md          | 185 ++++++
 .../dashboards/dashboards_context_spec_problems.md |   2 +
 .../dashboards/visualization_component_spec.md     | 130 ++++
 .../visualization_component_spec_problems.md       |   2 +
 .../invitations/invitation_component_code.md       |  78 +++
 .../invitation_component_code_problems.md          |  14 +
 .../invitations/invitation_component_spec.md       | 145 +++++
 .../invitation_component_spec_problems.md          |   2 +
 .../invitations/invitation_component_test.md       |  62 ++
 .../invitation_component_test_problems.md          |   2 +
 .../invitation_notifier_component_spec.md          | 145 +++++
 .../invitation_notifier_component_spec_problems.md |   3 +
 .../invitation_notifier_component_test.md          |  62 ++
 .../invitation_notifier_component_test_problems.md |   2 +
 .../invitation_repository_component_spec.md        | 145 +++++
 ...nvitation_repository_component_spec_problems.md |   2 +
 .../invitation_repository_component_test.md        |  62 ++
 ...nvitation_repository_component_test_problems.md |   2 +
 .../invitations/invitations_component_code.md      |  78 +++
 .../invitations_component_code_problems.md         | 189 ++++++
 .../invitations/invitations_component_test.md      |  62 ++
 .../invitations_component_test_problems.md         |   2 +
 .../invitations_context_component_specs.md         |  16 +
 ...invitations_context_component_specs_problems.md |   3 +
 .../invitations_context_design_review.md           | 138 ++++
 .../invitations_context_design_review_problems.md  |   3 +
 .../invitations_context_implementation.md          |  22 +
 .../invitations_context_implementation_problems.md |   4 +
 .../invitations/invitations_context_spec.md        | 185 ++++++
 .../invitations_context_spec_problems.md           |   2 +
 .../ai_live/chat/chat_live_view_spec.md            | 208 ++++++
 .../ai_live/chat/chat_live_view_spec_problems.md   |   2 +
 .../ai_live/insights/insights_live_view_spec.md    | 208 ++++++
 .../insights/insights_live_view_spec_problems.md   |   2 +
 .../correlation_live/index/index_live_view_spec.md | 208 ++++++
 .../index/index_live_view_spec_problems.md         |   2 +
 ...ricflowweb_dashboardlive_show_live_view_spec.md | 208 ++++++
 ...b_dashboardlive_show_live_view_spec_problems.md |   2 +
 .../dashboard_live/show/show_live_view_spec.md     | 208 ++++++
 .../show/show_live_view_spec_problems.md           |   2 +
 ...b_integrationlive_synchistory_live_view_spec.md | 208 ++++++
 ...tionlive_synchistory_live_view_spec_problems.md |   2 +
 .../accept/accept_component_code.md                | 129 ++++
 .../accept/accept_component_code_problems.md       |   2 +
 .../accept/accept_component_test.md                |  64 ++
 .../accept/accept_component_test_problems.md       |   2 +
 .../accept/accept_live_view_spec.md                | 208 ++++++
 .../accept/accept_live_view_spec_problems.md       |   2 +
 .../invitation_live/send/send_component_code.md    | 129 ++++
 .../send/send_component_code_problems.md           |   2 +
 .../invitation_live/send/send_component_test.md    |  64 ++
 .../send/send_component_test_problems.md           |   2 +
 .../invitation_live/send/send_live_view_spec.md    | 208 ++++++
 .../send/send_live_view_spec_problems.md           |   2 +
 .code_my_spec/tasks/qa/story_428_qa_story.md       | 147 +++++
 .code_my_spec/tasks/qa/story_429_qa_story.md       | 148 +++++
 .../428/subagent_prompts/bdd_specs_prompt.md       | 697 +++++++++++++++++++++
 .code_my_spec/tasks/stories/428/write_bdd_specs.md |  22 +
 .../429/subagent_prompts/bdd_specs_prompt.md       | 666 ++++++++++++++++++++
 .code_my_spec/tasks/stories/429/write_bdd_specs.md |  22 +
 config/runtime.exs                                 |   7 +-
 config/test.exs                                    |  17 +-
 lib/metric_flow.ex                                 |   2 +
 lib/metric_flow/invitations.ex                     | 437 +++++++++++++
 lib/metric_flow/invitations/invitation.ex          | 151 +++++
 lib/metric_flow/invitations/invitation_notifier.ex |  58 ++
 .../invitations/invitation_repository.ex           |  86 +++
 lib/metric_flow_web/components/layouts.ex          |  35 +-
 lib/metric_flow_web/hooks/active_account_hook.ex   |  28 +
 lib/metric_flow_web/live/account_live/index.ex     |   2 +-
 lib/metric_flow_web/live/account_live/settings.ex  | 164 ++++-
 lib/metric_flow_web/live/ai_live/chat.ex           | 254 +++++---
 lib/metric_flow_web/live/dashboard_live/show.ex    |  68 +-
 .../live/integration_live/account_edit.ex          |  37 +-
 lib/metric_flow_web/live/integration_live/index.ex | 359 +++++++++--
 lib/metric_flow_web/live/invitation_live/accept.ex | 213 +++++++
 lib/metric_flow_web/live/invitation_live/send.ex   | 317 ++++++++++
 lib/metric_flow_web/live/user_live/registration.ex |   2 +
 lib/metric_flow_web/router.ex                      |  13 +-
 priv/knowledge/devops/resend-setup.md              | 396 ++++++++++++
 .../20260307000001_create_invitations.exs          |  22 +
 ...add_accepted_at_and_declined_to_invitations.exs |  10 +
 priv/repo/qa_seeds_429.exs                         | 159 +++++
 priv/repo/qa_seeds_447.exs                         | 193 ++++++
 priv/repo/qa_seeds_450.exs                         | 223 +++++++
 priv/repo/qa_seeds_454.exs                         | 194 ++++++
 test/cassettes/ai/vega_spec_missing_encoding.json  |  43 ++
 test/cassettes/ai/vega_spec_missing_mark.json      |  43 ++
 test/cassettes/ai/vega_spec_missing_schema.json    |  43 ++
 test/metric_flow/ai_test.exs                       |  79 ++-
 test/metric_flow/correlations/math_test.exs        |  12 +-
 test/metric_flow/correlations_test.exs             | 460 ++++++++------
 test/metric_flow/dashboards_test.exs               |  49 +-
 .../invitations/invitation_notifier_test.exs       |  88 +++
 .../invitations/invitation_repository_test.exs     | 515 +++++++++++++++
 test/metric_flow/invitations/invitation_test.exs   | 428 +++++++++++++
 test/metric_flow/invitations_test.exs              | 630 +++++++++++++++++++
 .../live/invitation_live/accept_test.exs           | 416 ++++++++++++
 .../live/invitation_live/send_test.exs             | 434 +++++++++++++
 ...their_account_with_their_access_levels_spex.exs |   2 +-
 ...same_data_with_account-level_isolation_spex.exs |   2 +-
 ...any_email_address_agency_or_individual_spex.exs |  76 +++
 ...re_link_with_expiration_time_of_7_days_spex.exs |  94 +++
 ...ceives_invitation_in_their_email_inbox_spex.exs | 108 ++++
 ...nt_name_and_access_level_being_granted_spex.exs | 128 ++++
 ...ion_read-only_account_manager_or_admin_spex.exs | 111 ++++
 ...lidated_after_acceptance_or_expiration_spex.exs | 158 +++++
 ...ions_and_cancel_them_before_acceptance_spex.exs | 133 ++++
 ..._or_users_with_different_access_levels_spex.exs | 149 +++++
 ...n_link_and_is_taken_to_acceptance_page_spex.exs | 103 +++
 ...user_is_prompted_to_log_in_or_register_spex.exs | 120 ++++
 ...ecified_access_level_to_client_account_spex.exs | 133 ++++
 ...dded_to_their_account_switcher_or_list_spex.exs | 121 ++++
 ...d_invitations_show_clear_error_message_spex.exs | 147 +++++
 ...-accepted_invitations_cannot_be_reused_spex.exs | 131 ++++
 ..._access_based_on_agency_team_structure_spex.exs | 179 ++++++
 ...all_users_with_access_to_their_account_spex.exs |   4 +-
 ...nd_whether_they_are_account_originator_spex.exs |   2 +-
 ...tely_loses_ability_to_view_client_data_spex.exs |   2 +-
 ...oked_only_ownership_can_be_transferred_spex.exs |   2 +-
 ...terday_to_avoid_incomplete_current_day_spex.exs |   2 +-
 ...ing_visible_on_white-labeled_instances_spex.exs |   6 +-
 ...tom_subdomain_they_see_agency_branding_spex.exs |   6 +-
 ...ency_logo_appears_in_navigation_header_spex.exs |   6 +-
 ...scheme_is_applied_throughout_interface_spex.exs |   6 +-
 ...ling_is_always_applied_for_that_client_spex.exs |   6 +-
 ...ashboards_regardless_of_white-labeling_spex.exs |   6 +-
 ...t_functionality_only_visual_appearance_spex.exs |   9 +-
 test/support/metric_flow_test_boundary.ex          |   2 +-
 test/support/shared_givens.ex                      |  97 ++-
 422 files changed, 30263 insertions(+), 674 deletions(-)
## 7cf55a8 - Replace default Phoenix landing page with MetricFlow home page

Date: 2026-03-07 13:16:48 -0500
Author: John Davenport


 .../controllers/page_html/home.html.heex           | 301 ++++++++-------------
 1 file changed, 116 insertions(+), 185 deletions(-)
## 30691b7 - Update CodeMySpec specs, architecture, status, and session logs

Date: 2026-03-06 08:20:46 -0500
Author: John Davenport


 .code_my_spec/architecture/dependency_graph.mmd    |   1 +
 .code_my_spec/architecture/namespace_hierarchy.md  |  22 +-
 .code_my_spec/architecture/overview.md             |  24 +-
 .code_my_spec/design/design_system.html            |  54 +-
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../subagent_prompts/bdd_specs_story_441.md        | 654 +++++++++++++++++++++
 .../write_bdd_specs.md                             |  22 +
 .../subagent_prompts/bdd_specs_story_451.md        | 629 ++++++++++++++++++++
 .../write_bdd_specs.md                             |  22 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../write_bdd_specs.md                             |  22 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../agencies/agency_client_access_grant.spec.md    |  91 +++
 .../spec/metric_flow/agencies/design_review.md     |  34 ++
 .../spec/metric_flow/ai/ai_repository.spec.md      | 232 ++++++++
 .code_my_spec/spec/metric_flow/ai/design_review.md |  34 ++
 .../spec/metric_flow/correlations/design_review.md |  34 ++
 .../spec/metric_flow/correlations/math.spec.md     | 102 ++++
 .../metric_flow/dashboards/chart_builder.spec.md   |  88 +++
 .../spec/metric_flow/dashboards/design_review.md   |  37 ++
 .../metric_flow_web/account_live/index.spec.md     | 123 ++--
 .../metric_flow_web/agency_live/settings.spec.md   |  59 +-
 .../metric_flow_web/integration_live/index.spec.md |  54 +-
 .../spec/metric_flow_web/user_live/login.spec.md   |  39 +-
 .code_my_spec/status/implementation_status.json    |   2 +-
 .code_my_spec/status/metric flow_fix_issues.md     | 179 ++++++
 .../status/metric flow_fix_issues_problems.md      |   9 +
 .code_my_spec/status/metric flow_triage_issues.md  | 177 ++++++
 .../status/metric flow_triage_issues_problems.md   |  10 +
 .code_my_spec/status/metric_flow.md                |  60 +-
 .code_my_spec/status/metric_flow/accounts.md       |   7 +-
 .code_my_spec/status/metric_flow/agencies.md       |  33 +-
 ...w_agencies_agenciesrepository_component_test.md |  62 ++
 ...s_agenciesrepository_component_test_problems.md |   2 +
 .../agencies/metricflow_agencies_component_test.md |  62 ++
 .../metricflow_agencies_component_test_problems.md |   2 +
 .code_my_spec/status/metric_flow/ai.md             |  41 +-
 .../status/metric_flow/ai/develop_context.md       |  51 ++
 .../ai/metricflow_ai_airepository_code.md          |  76 +++
 .../ai/metricflow_ai_airepository_test.md          |  64 ++
 .../ai/metricflow_ai_chatmessage_code.md           |  88 +++
 .../ai/metricflow_ai_chatsession_code.md           |  88 +++
 .../status/metric_flow/ai/metricflow_ai_code.md    |  76 +++
 .../metric_flow/ai/metricflow_ai_insight_code.md   |  88 +++
 .../ai/metricflow_ai_insightsgenerator_code.md     |  76 +++
 .../ai/metricflow_ai_insightsgenerator_test.md     |  64 ++
 .../metric_flow/ai/metricflow_ai_llmclient_code.md |  76 +++
 .../metric_flow/ai/metricflow_ai_llmclient_test.md |  64 ++
 .../ai/metricflow_ai_reportgenerator_code.md       |  76 +++
 .../ai/metricflow_ai_reportgenerator_test.md       |  64 ++
 .../ai/metricflow_ai_suggestionfeedback_code.md    |  88 +++
 .../status/metric_flow/ai/metricflow_ai_test.md    |  62 ++
 .code_my_spec/status/metric_flow/correlations.md   |  33 +-
 .../metric_flow/correlations/develop_context.md    |  54 ++
 .../correlations/metricflow_correlations_code.md   |  76 +++
 .../metricflow_correlations_correlationjob_code.md |  88 +++
 ...tricflow_correlations_correlationresult_code.md |  88 +++
 ...low_correlations_correlationsrepository_code.md |  76 +++
 ...low_correlations_correlationsrepository_test.md |  64 ++
 ...tricflow_correlations_correlationworker_code.md |  76 +++
 ...tricflow_correlations_correlationworker_test.md |  62 ++
 .../metricflow_correlations_math_code.md           |  76 +++
 .../metricflow_correlations_math_test.md           |  62 ++
 .../correlations/metricflow_correlations_test.md   |  62 ++
 .code_my_spec/status/metric_flow/dashboards.md     |  35 +-
 .code_my_spec/status/metric_flow/data_sync.md      |   9 +-
 .code_my_spec/status/metric_flow/integrations.md   |   7 +-
 .code_my_spec/status/metric_flow/invitations.md    |   7 +-
 .code_my_spec/status/metric_flow/metrics.md        |   7 +-
 .code_my_spec/status/metric_flow/release.md        |  11 +
 .code_my_spec/status/metric_flow/users.md          |   7 +-
 .code_my_spec/status/metric_flow_web.md            |  60 +-
 .../status/metric_flow_web/account_live.md         |   7 +-
 ...tricflowweb_accountlive_index_live_view_spec.md | 208 +++++++
 ...eb_accountlive_index_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/agency_live.md          |   7 +-
 ...icflowweb_agencylive_settings_live_view_spec.md | 208 +++++++
 ..._agencylive_settings_live_view_spec_problems.md |   2 +
 .code_my_spec/status/metric_flow_web/ai_live.md    |  11 +-
 .../ai_live/chat/develop_live_view.md              |  47 ++
 .../ai_live/chat/metricflowweb_ailive_chat_code.md | 146 +++++
 .../ai_live/chat/metricflowweb_ailive_chat_test.md |  64 ++
 .../status/metric_flow_web/correlation_live.md     |   6 +-
 .../status/metric_flow_web/dashboard_live.md       |   7 +-
 .code_my_spec/status/metric_flow_web/dev.md        |  17 +
 .../status/metric_flow_web/health_controller.md    |  11 +
 .../status/metric_flow_web/integration_live.md     |  21 +-
 ...flowweb_integrationlive_index_live_view_spec.md | 208 +++++++
 ...ntegrationlive_index_live_view_spec_problems.md |   2 +
 ...b_integrationlive_synchistory_live_view_spec.md | 208 +++++++
 ...tionlive_synchistory_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/invitation_live.md      |   2 +
 .code_my_spec/status/metric_flow_web/plugs.md      |  17 +
 .code_my_spec/status/metric_flow_web/user_live.md  |   5 +-
 .../metricflowweb_userlive_login_live_view_spec.md | 208 +++++++
 ...owweb_userlive_login_live_view_spec_problems.md |   2 +
 .../status/metric_flow_web/visualization_live.md   |   1 +
 .../status/metric_flow_web/white_label_hook.md     |  11 +
 .code_my_spec/status/project.md                    |  11 +
 .code_my_spec/status/qa/story_424_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_425_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_426_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_427_qa_story.md      | 143 +++++
 .code_my_spec/status/qa/story_430_qa_story.md      | 145 +++++
 .code_my_spec/status/qa/story_431_qa_story.md      | 149 +++++
 .code_my_spec/status/qa/story_434_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_436_qa_story.md      | 148 +++++
 .code_my_spec/status/qa/story_438_qa_story.md      | 143 +++++
 .code_my_spec/status/qa/story_455_qa_story.md      | 148 +++++
 .code_my_spec/status/stories.md                    | 394 +++++++++++++
 127 files changed, 8193 insertions(+), 214 deletions(-)
## a9e404a - Add QA issues, test results, and seed data

Date: 2026-03-06 08:20:37 -0500
Author: John Davenport


 ...25-post_users_log_in_with_email_only_body_re.md |  28 +++
 ...26-vibium_mcp_server_not_configured_browser_.md |  50 ++++
 ...27-role_change_via_phx_change_select_does_no.md |  31 +++
 ...30-invite_form_defaults_to_owner_role_when_n.md |  31 +++
 ...30-phx_change_on_select_elements_does_not_fi.md |  31 +++
 ...31-accountlive_index_does_not_display_agency.md |  28 +++
 ...31-accountlive_index_missing_switch_account_.md |  30 +++
 ...31-members_list_and_member_rows_missing_data.md |  27 +++
 ...31-navigation_missing_current_account_name_i.md |  27 +++
 ...31-read_only_and_account_manager_users_can_s.md |  26 ++
 ...tegrations_index_missing_canonical_platforms.md |  30 +++
 ...34-unsupported_platform_card_visible_in_grid.md |  31 +++
 ...36-qa_environment_requires_server_restart_to.md |  37 +++
 ...38-syncworker_does_not_handle_the_google_pro.md |  32 +++
 ...38-syncworker_never_sends_sync_completion_or.md |  36 +++
 ...25-vibium_daemon_stale_socket_blocks_browser.md |  24 ++
 ...26-vibium_mcp_server_unavailable_browser_sce.md |  18 ++
 ...27-logout_link_in_user_dropdown_has_zero_vis.md |  21 ++
 ...27-missing_dev_children_0_function_causes_se.md |  21 ++
 ...27-registration_form_submit_silently_fails_a.md |  21 ++
 ...31-active_account_defaults_to_most_recently_.md |  21 ++
 ...31-seed_script_may_resolve_incorrect_agency_.md |  21 ++
 ...oauth_connect_button_falls_back_to_phx_click.md |  21 ++
 ...36-canonical_platforms_missing_from_availabl.md |  24 ++
 ...36-connected_integration_card_not_rendered_d.md |  31 +++
 ...55-vibium_mcp_browser_tools_unavailable_brow.md |  21 ++
 ...-vibium_mcp_browser_tools_unavailable_brow_2.md |  20 ++
 .code_my_spec/qa/424/brief.md                      | 156 ++++++++++++
 .code_my_spec/qa/424/result.md                     | 200 +++++++++++++++
 .../qa/424/screenshots/01-registration-form.png    | Bin 0 -> 36973 bytes
 .../screenshots/01_registration_form_initial.png   | Bin 0 -> 36498 bytes
 .../screenshots/02_registration_form_filled.png    | Bin 0 -> 40130 bytes
 .../qa/424/screenshots/02_registration_success.png | Bin 0 -> 36908 bytes
 .../03_dev_mailbox_confirmation_email.png          | Bin 0 -> 66057 bytes
 .../screenshots/04_password_too_short_error.png    | Bin 0 -> 43440 bytes
 .../qa/424/screenshots/05_invalid_email_error.png  | Bin 0 -> 44608 bytes
 .../424/screenshots/06_duplicate_email_error.png   | Bin 0 -> 41960 bytes
 .../screenshots/07_missing_account_name_error.png  | Bin 0 -> 42853 bytes
 .../qa/424/screenshots/08a_logged_in_home.png      | Bin 0 -> 75029 bytes
 .../08b_logged_in_register_redirect.png            | Bin 0 -> 76364 bytes
 .../qa/424/screenshots/09_explore_xss_escaped.png  | Bin 0 -> 37808 bytes
 .../424/screenshots/10_explore_no_account_type.png | Bin 0 -> 36298 bytes
 .code_my_spec/qa/425/brief.md                      | 187 ++++++++++++++
 .code_my_spec/qa/425/result.md                     | 222 +++++++++++++++++
 .../qa/425/screenshots/01_login_page.html          | 218 +++++++++++++++++
 .../qa/425/screenshots/02_login_success_home.html  | 219 +++++++++++++++++
 .../screenshots/04_login_error_wrong_password.html | 231 ++++++++++++++++++
 .../screenshots/05_login_error_unregistered.html   | 231 ++++++++++++++++++
 .../qa/425/screenshots/06_login_error_empty.html   | 231 ++++++++++++++++++
 .../425/screenshots/07_settings_authenticated.html | 214 ++++++++++++++++
 .../425/screenshots/08_accounts_authenticated.html | 229 ++++++++++++++++++
 .../screenshots/09_settings_with_logout_link.html  | 214 ++++++++++++++++
 .../qa/425/screenshots/10_logged_out.html          | 216 +++++++++++++++++
 .../425/screenshots/11_post_logout_redirect.html   | 244 +++++++++++++++++++
 .../screenshots/12_unauthenticated_redirect.html   | 231 ++++++++++++++++++
 .../qa/425/screenshots/13_remember_me_buttons.html | 218 +++++++++++++++++
 .code_my_spec/qa/426/brief.md                      | 202 ++++++++++++++++
 .code_my_spec/qa/426/result.md                     | 154 ++++++++++++
 .code_my_spec/qa/427/brief.md                      | 142 +++++++++++
 .code_my_spec/qa/427/result.md                     | 182 ++++++++++++++
 .code_my_spec/qa/430/brief.md                      | 159 ++++++++++++
 .code_my_spec/qa/430/result.md                     | 145 +++++++++++
 .../430/screenshots/01-members-list-owner-view.png | Bin 0 -> 31737 bytes
 .../qa/430/screenshots/02-member-row-fields.png    | Bin 0 -> 32898 bytes
 .../screenshots/03-after-invite-two-members.png    | Bin 0 -> 32898 bytes
 .../430/screenshots/04-role-change-attempted.png   | Bin 0 -> 33006 bytes
 .../screenshots/04-role-change-select-no-event.png | Bin 0 -> 29837 bytes
 .../qa/430/screenshots/05-member-removed.png       | Bin 0 -> 22459 bytes
 .../qa/430/screenshots/06-owner-removed-member.png | Bin 0 -> 29969 bytes
 .../06-removed-member-access-denied.png            | Bin 0 -> 26279 bytes
 .../screenshots/07-no-remove-for-sole-owner.png    | Bin 0 -> 32898 bytes
 .../screenshots/08-unauthenticated-redirect.png    | Bin 0 -> 31025 bytes
 .../430/screenshots/09-permission-change-flash.png | Bin 0 -> 29969 bytes
 .code_my_spec/qa/431/brief.md                      | 213 ++++++++++++++++
 .code_my_spec/qa/431/result.md                     | 246 +++++++++++++++++++
 .../qa/431/screenshots/01-accounts-page-owner.png  | Bin 0 -> 64854 bytes
 .../431/screenshots/02-accounts-settings-owner.png | Bin 0 -> 48523 bytes
 .../qa/431/screenshots/03-integrations-page.png    | Bin 0 -> 47689 bytes
 .../screenshots/04-accounts-page-readonly-user.png | Bin 0 -> 23228 bytes
 .../431/screenshots/05-settings-readonly-user.png  | Bin 0 -> 34624 bytes
 .../431/screenshots/06-members-readonly-user.png   | Bin 0 -> 53648 bytes
 .../qa/431/screenshots/07-integrations-acctmgr.png | Bin 0 -> 40105 bytes
 .../qa/431/screenshots/08-settings-acctmgr.png     | Bin 0 -> 35975 bytes
 .../qa/431/screenshots/09-members-acctmgr.png      | Bin 0 -> 56997 bytes
 .../qa/431/screenshots/10-settings-admin.png       | Bin 0 -> 36245 bytes
 .../qa/431/screenshots/11-members-admin.png        | Bin 0 -> 69919 bytes
 .../qa/431/screenshots/12-accounts-page-final.png  | Bin 0 -> 51640 bytes
 .code_my_spec/qa/434/brief.md                      | 141 +++++++++++
 .code_my_spec/qa/434/result.md                     | 268 +++++++++++++++++++++
 .../screenshots/s10_connect_detail_no_transfer.png | Bin 0 -> 38121 bytes
 .../qa/434/screenshots/s10_integrations_list.png   | Bin 0 -> 32927 bytes
 .../434/screenshots/s10_integrations_list_full.png | Bin 0 -> 44373 bytes
 .../qa/434/screenshots/s1_platform_selection.png   | Bin 0 -> 38115 bytes
 .../434/screenshots/s1_platform_selection_full.png | Bin 0 -> 69887 bytes
 .../qa/434/screenshots/s3_google_ads_detail.png    | Bin 0 -> 38121 bytes
 .../s5_account_selection_google_ads.png            | Bin 0 -> 41197 bytes
 .../s5_account_selection_google_analytics.png      | Bin 0 -> 42037 bytes
 .../qa/434/screenshots/s7_callback_error_state.png | Bin 0 -> 30148 bytes
 .../434/screenshots/s8_callback_access_denied.png  | Bin 0 -> 30148 bytes
 .code_my_spec/qa/436/brief.md                      | 183 ++++++++++++++
 .code_my_spec/qa/436/result.md                     | 201 ++++++++++++++++
 .code_my_spec/qa/436/screenshots/00-login-page.png | Bin 0 -> 18671 bytes
 .../qa/436/screenshots/01-integrations-index.png   | Bin 0 -> 40503 bytes
 .../screenshots/02-connected-platforms-empty.png   | Bin 0 -> 40503 bytes
 .../qa/436/screenshots/03-reconnect-flash.png      | Bin 0 -> 29860 bytes
 .../qa/436/screenshots/04-final-state.png          | Bin 0 -> 40503 bytes
 .code_my_spec/qa/438/brief.md                      | 141 +++++++++++
 .code_my_spec/qa/438/result.md                     | 113 +++++++++
 .../screenshots/01_integrations_page_initial.png   | Bin 0 -> 50205 bytes
 .../438/screenshots/02_sync_now_button_enabled.png | Bin 0 -> 42061 bytes
 .../438/screenshots/03_after_sync_now_clicked.png  | Bin 0 -> 42938 bytes
 .../screenshots/04_syncing_stuck_no_completion.png | Bin 0 -> 51210 bytes
 .../screenshots/05_unauthenticated_redirect.png    | Bin 0 -> 31038 bytes
 .code_my_spec/qa/455/brief.md                      | 167 +++++++++++++
 .code_my_spec/qa/455/result.md                     | 106 ++++++++
 .code_my_spec/qa/plan.md                           | 175 ++++++++++++++
 .code_my_spec/qa/scripts/login.sh                  |  16 ++
 .code_my_spec/qa/scripts/logout.sh                 |  12 +
 .code_my_spec/qa/scripts/start-qa.sh               |  51 ++++
 priv/repo/qa_integration_seed.exs                  |  26 ++
 priv/repo/qa_seeds.exs                             | 118 +++++++++
 priv/repo/qa_seeds_438.exs                         |  30 +++
 priv/repo/qa_seeds_story_431.exs                   | 160 ++++++++++++
 123 files changed, 7551 insertions(+)
## cbf7ddf - Add BDD Spex tests for stories 427-495

Date: 2026-03-06 08:20:26 -0500
Author: John Davenport


 ...auto-enrollment_for_their_email_domain_spex.exs |  76 +++++
 ..._automatically_added_to_agency_account_spex.exs |  92 ++++++
 ...fault_access_level_set_by_agency_admin_spex.exs | 101 ++++++
 ..._manage_all_auto-enrolled_team_members_spex.exs | 138 ++++++++
 ...can_disable_auto-enrollment_if_desired_spex.exs | 110 +++++++
 ...all_client_accounts_the_agency_manages_spex.exs | 171 ++++++++++
 ...ll_client_accounts_they_have_access_to_spex.exs |  79 +++++
 ...ws_access_level_and_origination_status_spex.exs | 119 +++++++
 ...n_client_accounts_via_account_switcher_spex.exs | 169 ++++++++++
 ...ext_is_clearly_displayed_in_navigation_spex.exs | 137 ++++++++
 ...s_can_only_view_reports_and_dashboards_spex.exs | 217 +++++++++++++
 ...but_not_delete_account_or_manage_users_spex.exs | 221 +++++++++++++
 ...o_everything_except_delete_the_account_spex.exs | 257 +++++++++++++++
 ..._account_unless_they_have_admin_access_spex.exs | 165 ++++++++++
 ...ient_account_they_see_originator_badge_spex.exs | 134 ++++++++
 ...sync_job_at_scheduled_time_eg_2_am_utc_spex.exs |  82 +++++
 ...l_active_integrations_for_all_accounts_spex.exs | 115 +++++++
 ...vailable_historical_data_from_platform_spex.exs | 105 ++++++
 ...as_metrics_alongside_marketing_metrics_spex.exs | 121 +++++++
 ...w_data_and_financial_data_for_each_day_spex.exs | 164 ++++++++++
 ...re_automatically_refreshed_when_needed_spex.exs | 108 +++++++
 ...up_to_3_times_with_exponential_backoff_spex.exs | 161 +++++++++
 ..._are_logged_with_details_for_debugging_spex.exs | 164 ++++++++++
 ..._avoid_showing_zero_for_incomplete_day_spex.exs | 111 +++++++
 ...ync_now_button_in_integration_settings_spex.exs |  57 ++++
 ...mediate_data_pull_for_that_integration_spex.exs |  54 ++++
 ...ync_in_progress_with_loading_indicator_spex.exs |  71 ++++
 ...sage_with_timestamp_and_records_synced_spex.exs | 118 +++++++
 ...sync_fails_error_details_are_displayed_spex.exs |  98 ++++++
 ...ere_with_automated_daily_sync_schedule_spex.exs | 128 ++++++++
 ...n_shows_last_successful_sync_timestamp_spex.exs | 153 +++++++++
 ...gration_shows_next_scheduled_sync_time_spex.exs | 103 ++++++
 ...led_sync_history_last_30_syncs_minimum_spex.exs | 152 +++++++++
 ..._records_synced_and_any_error_messages_spex.exs | 253 +++++++++++++++
 ...ncs_are_highlighted_with_error_details_spex.exs | 141 ++++++++
 ...c_history_by_status_all_success_failed_spex.exs | 234 ++++++++++++++
 ...wing_data_from_all_connected_platforms_spex.exs | 117 +++++++
 ..._financial_metrics_with_no_distinction_spex.exs |  99 ++++++
 ..._by_platform_date_range_or_metric_type_spex.exs | 188 +++++++++++
 ...7_days_30_days_90_days_all_time_custom_spex.exs | 360 +++++++++++++++++++++
 ...terday_to_avoid_incomplete_current_day_spex.exs | 142 ++++++++
 ...pdates_dynamically_when_filters_change_spex.exs | 210 ++++++++++++
 ...ted_dashboard_shows_onboarding_prompts_spex.exs | 141 ++++++++
 ..._4075_all_visualizations_use_vega-lite_spex.exs | 120 +++++++
 ..._all_metrics_and_selected_goal_metrics_spex.exs |  68 ++++
 ...ulated_daily_after_data_sync_completes_spex.exs |  59 ++++
 ...tric_to_automatically_find_optimal_lag_spex.exs |  59 ++++
 ...lute_correlation_value_for_each_metric_spex.exs |  73 +++++
 ...calculations_use_daily_aggregated_data_spex.exs |  60 ++++
 ...hold_are_calculated_eg_30_days_of_data_spex.exs |  64 ++++
 ...nancial_and_marketing_treated_the_same_spex.exs |  60 ++++
 ...le_ai_suggestions_option_in_smart_mode_spex.exs | 100 ++++++
 ..._based_on_085_correlation_with_revenue_spex.exs | 142 ++++++++
 ...sualization_can_have_an_ai_info_button_spex.exs |  85 +++++
 ...sights_or_opens_chat_about_that_metric_spex.exs | 241 ++++++++++++++
 ...n_strength_trends_and_business_context_spex.exs | 171 ++++++++++
 ..._on_suggestions_helpful_or_not_helpful_spex.exs | 196 +++++++++++
 ...feedback_to_improve_future_suggestions_spex.exs | 172 ++++++++++
 ..._chat_from_any_report_or_visualization_spex.exs | 167 ++++++++++
 ...cludes_relevant_data_from_current_view_spex.exs | 208 ++++++++++++
 ...like_why_did_my_revenue_drop_last_week_spex.exs | 189 +++++++++++
 ...metrics_and_correlation_data_to_answer_spex.exs | 203 ++++++++++++
 ...izations_or_reports_based_on_questions_spex.exs | 210 ++++++++++++
 ...on_4143_chat_history_is_saved_per_user_spex.exs | 202 ++++++++++++
 ..._share_chat_insights_with_team_members_spex.exs | 229 +++++++++++++
 ...pload_custom_logo_supports_png_jpg_svg_spex.exs | 130 ++++++++
 ...scheme_primary_secondary_accent_colors_spex.exs | 134 ++++++++
 ...subdomain_eg_reportsandersonthefishcom_spex.exs |  97 ++++++
 ...ges_preview_in_real-time_before_saving_spex.exs | 153 +++++++++
 ...6_agency_can_reset_to_default_branding_spex.exs | 112 +++++++
 ...ngs_are_stored_at_agency_account_level_spex.exs | 190 +++++++++++
 ...res_dns_verification_before_activation_spex.exs | 107 ++++++
 ...ing_visible_on_white-labeled_instances_spex.exs | 142 ++++++++
 ...tom_subdomain_they_see_agency_branding_spex.exs |  85 +++++
 ...ency_logo_appears_in_navigation_header_spex.exs |  90 ++++++
 ...scheme_is_applied_throughout_interface_spex.exs |  95 ++++++
 ..._main_domain_they_see_default_branding_spex.exs |  98 ++++++
 ...ling_is_always_applied_for_that_client_spex.exs |  92 ++++++
 ...ashboards_regardless_of_white-labeling_spex.exs |  91 ++++++
 ...t_functionality_only_visual_appearance_spex.exs | 139 ++++++++
 ..._that_platform-specific_metrics_map_to_spex.exs | 152 +++++++++
 ...nk_clicks_both_map_to_canonical_clicks_spex.exs | 130 ++++++++
 ...fic_metric_and_clearly_labeled_as_such_spex.exs | 146 +++++++++
 ..._are_mapped_to_which_canonical_metrics_spex.exs | 157 +++++++++
 ...ards_and_reports_using_canonical_names_spex.exs | 159 +++++++++
 ..._facebook_ads_clicks_on_the_same_chart_spex.exs | 133 ++++++++
 ...s_warnings_or_footnotes_when_comparing_spex.exs | 163 ++++++++++
 ...nges_to_existing_canonical_definitions_spex.exs | 163 ++++++++++
 ...forms_once_their_components_are_mapped_spex.exs | 145 +++++++++
 ...etrics_eg_cpc_ctr_conversion_rate_roas_spex.exs | 120 +++++++
 ...etrics_eg_cpc_total_spend_total_clicks_spex.exs | 132 ++++++++
 ...d_value_from_the_aggregated_components_spex.exs | 155 +++++++++
 ...d_value_from_the_aggregated_components_spex.exs | 129 ++++++++
 ..._re-derives_from_aggregated_components_spex.exs | 121 +++++++
 ...d_can_be_extended_for_new_metric_types_spex.exs | 123 +++++++
 ...an_silently_producing_incorrect_values_spex.exs | 133 ++++++++
 ...ation_logic_is_transparent_to_the_user_spex.exs | 163 ++++++++++
 test/spex/metric_flow_spex.ex                      |  11 +
 98 files changed, 13404 insertions(+)
## 8c28dd6 - Add tests for domain contexts, LiveViews, and AI cassettes

Date: 2026-03-06 08:20:15 -0500
Author: John Davenport


 .../cassettes/ai/ai_context_generate_insights.json |  217 ++++
 .../ai/ai_context_generate_vega_spec.json          |  369 +++++++
 test/cassettes/ai/generate_insights.json           |  179 +++
 test/cassettes/ai/generate_vega_spec.json          |  168 +++
 test/cassettes/ai/insights_generator_empty.json    |  217 ++++
 test/cassettes/ai/insights_generator_error.json    |  206 ++++
 test/cassettes/ai/insights_generator_single.json   |  179 +++
 test/cassettes/ai/insights_generator_success.json  |  179 +++
 test/cassettes/ai/report_generator_error.json      |  195 ++++
 test/cassettes/ai/report_generator_success.json    |  168 +++
 .../agencies/agencies_repository_test.exs          |  981 +++++++++++++++++
 .../agencies/agency_client_access_grant_test.exs   |  513 +++++++++
 .../agencies/auto_enrollment_rule_test.exs         |  345 ++++++
 .../agencies/white_label_config_test.exs           |  411 +++++++
 test/metric_flow/agencies_test.exs                 |  891 +++++++++++++++
 test/metric_flow/ai/ai_repository_test.exs         |  636 +++++++++++
 test/metric_flow/ai/chat_message_test.exs          |  200 ++++
 test/metric_flow/ai/chat_session_test.exs          |  300 ++++++
 test/metric_flow/ai/insight_test.exs               |  378 +++++++
 test/metric_flow/ai/insights_generator_test.exs    |  259 +++++
 test/metric_flow/ai/llm_client_test.exs            |  174 +++
 test/metric_flow/ai/report_generator_test.exs      |  149 +++
 test/metric_flow/ai/suggestion_feedback_test.exs   |  258 +++++
 test/metric_flow/ai_test.exs                       |  669 ++++++++++++
 .../correlations/correlation_worker_test.exs       |  363 +++++++
 .../correlations/correlations_repository_test.exs  |  552 ++++++++++
 test/metric_flow/correlations/math_test.exs        |  399 +++++++
 test/metric_flow/correlations_test.exs             |  525 +++++++++
 test/metric_flow/dashboards/chart_builder_test.exs |  238 ++++
 test/metric_flow/dashboards/dashboard_test.exs     |  266 +++++
 .../dashboards/dashboard_visualization_test.exs    |  344 ++++++
 .../dashboards/dashboards_repository_test.exs      |  189 ++++
 test/metric_flow/dashboards/visualization_test.exs |  263 +++++
 .../dashboards/visualizations_repository_test.exs  |  228 ++++
 test/metric_flow/dashboards_test.exs               |  466 ++++++++
 .../live/account_live/index_test.exs               |  589 ++++++++++
 .../live/account_live/members_test.exs             |   20 +-
 .../live/agency_live/settings_test.exs             |  594 ++++++++++
 test/metric_flow_web/live/ai_live/chat_test.exs    | 1136 ++++++++++++++++++++
 .../metric_flow_web/live/ai_live/insights_test.exs |  572 ++++++++++
 .../live/correlation_live/index_test.exs           |  876 +++++++++++++++
 .../live/dashboard_live/show_test.exs              |  496 +++++++++
 .../live/integration_live/index_test.exs           |  554 ++++++++++
 .../live/integration_live/sync_history_test.exs    |  657 +++++++++++
 test/support/fixtures/agencies_fixtures.ex         |  188 ++++
 test/support/fixtures/ai_fixtures.ex               |  223 ++++
 test/support/fixtures/integrations_fixtures.ex     |   29 +
 test/support/fixtures/users_fixtures.ex            |    8 +
 48 files changed, 18007 insertions(+), 9 deletions(-)
## 916feee - Add LiveViews, hooks, plugs, and update router and layouts

Date: 2026-03-06 08:20:01 -0500
Author: John Davenport


 lib/metric_flow_web/components/layouts.ex          |  93 +++-
 lib/metric_flow_web/hooks/white_label_hook.ex      |  15 +
 lib/metric_flow_web/live/account_live/index.ex     | 248 ++++++++-
 lib/metric_flow_web/live/account_live/members.ex   |  10 +-
 lib/metric_flow_web/live/agency_live/settings.ex   | 337 ++++++++++++
 lib/metric_flow_web/live/ai_live/chat.ex           | 557 +++++++++++++++++++
 lib/metric_flow_web/live/ai_live/insights.ex       | 327 +++++++++++
 lib/metric_flow_web/live/correlation_live/index.ex | 598 +++++++++++++++++++++
 lib/metric_flow_web/live/dashboard_live/show.ex    | 509 ++++++++++++++++++
 .../live/integration_live/account_edit.ex          | 158 ++++++
 .../live/integration_live/sync_history.ex          | 372 +++++++++++++
 lib/metric_flow_web/plugs/white_label.ex           |  51 ++
 lib/metric_flow_web/router.ex                      |  12 +
 13 files changed, 3246 insertions(+), 41 deletions(-)
## 990dd01 - Add Agencies, AI, Correlations, and Dashboards domain contexts with migrations

Date: 2026-03-06 08:19:48 -0500
Author: John Davenport


 lib/metric_flow/accounts.ex                        |   9 +
 lib/metric_flow/accounts/account_member.ex         |  14 +-
 lib/metric_flow/accounts/account_repository.ex     |  21 +-
 lib/metric_flow/agencies.ex                        | 526 +++++++++++++++++++++
 lib/metric_flow/agencies/agencies_repository.ex    | 365 ++++++++++++++
 .../agencies/agency_client_access_grant.ex         |  70 +++
 lib/metric_flow/agencies/auto_enrollment_rule.ex   |  59 +++
 lib/metric_flow/agencies/white_label_config.ex     |  71 +++
 lib/metric_flow/ai.ex                              | 280 +++++++++++
 lib/metric_flow/ai/ai_repository.ex                | 217 +++++++++
 lib/metric_flow/ai/chat_message.ex                 |  63 +++
 lib/metric_flow/ai/chat_session.ex                 | 102 ++++
 lib/metric_flow/ai/insight.ex                      | 114 +++++
 lib/metric_flow/ai/insights_generator.ex           | 117 +++++
 lib/metric_flow/ai/llm_client.ex                   | 145 ++++++
 lib/metric_flow/ai/report_generator.ex             |  61 +++
 lib/metric_flow/ai/suggestion_feedback.ex          |  60 +++
 lib/metric_flow/correlations.ex                    | 183 +++++++
 lib/metric_flow/correlations/correlation_job.ex    |  93 ++++
 lib/metric_flow/correlations/correlation_result.ex | 104 ++++
 lib/metric_flow/correlations/correlation_worker.ex | 197 ++++++++
 .../correlations/correlations_repository.ex        | 155 ++++++
 lib/metric_flow/correlations/math.ex               | 124 +++++
 lib/metric_flow/dashboards.ex                      | 242 ++++++++++
 lib/metric_flow/dashboards/chart_builder.ex        |  83 ++++
 lib/metric_flow/dashboards/dashboard.ex            |  69 +++
 .../dashboards/dashboard_visualization.ex          |  61 +++
 .../dashboards/dashboards_repository.ex            | 104 ++++
 lib/metric_flow/dashboards/visualization.ex        |  65 +++
 .../dashboards/visualizations_repository.ex        | 108 +++++
 ...20260224000002_create_auto_enrollment_rules.exs |  17 +
 .../20260224000003_create_white_label_configs.exs  |  19 +
 ...24000004_create_agency_client_access_grants.exs |  18 +
 ...24000005_add_member_role_to_account_members.exs |  15 +
 ...ique_index_to_white_label_configs_agency_id.exs |   8 +
 .../20260224100001_create_dashboards.exs           |  16 +
 .../20260224100002_create_visualizations.exs       |  17 +
 ...60224100003_create_dashboard_visualizations.exs |  18 +
 .../20260224200001_create_correlation_jobs.exs     |  23 +
 .../20260224200002_create_correlation_results.exs  |  29 ++
 .../migrations/20260225000001_create_insights.exs  |  23 +
 .../20260225000002_create_suggestion_feedback.exs  |  19 +
 .../20260225000003_create_chat_sessions.exs        |  20 +
 .../20260225000004_create_chat_messages.exs        |  17 +
 44 files changed, 4134 insertions(+), 7 deletions(-)
## 32114ed - Add Cloudflare dev tunnel and upgrade client_utils to 0.1.15

Date: 2026-03-06 01:26:50 -0500
Author: John Davenport


 config/dev.exs                     | 10 ++++++++-
 config/runtime.exs                 |  8 +++++++
 lib/metric_flow_web/application.ex | 43 +++++++++++++++++++++++++++-----------
 mix.exs                            |  6 +++---
 mix.lock                           |  2 +-
 5 files changed, 52 insertions(+), 17 deletions(-)
## 33dd630 - Add Docker deployment infrastructure for UAT on Hetzner

Date: 2026-03-06 01:26:21 -0500
Author: John Davenport


 Dockerfile                                         | 68 ++++++++++++++++++++++
 docker-compose.yml                                 | 56 ++++++++++++++++++
 lib/metric_flow/release.ex                         | 29 +++++++++
 .../controllers/health_controller.ex               |  9 +++
 rel/overlays/bin/migrate                           |  5 ++
 rel/overlays/bin/server                            |  5 ++
 scripts/deploy-uat                                 | 29 +++++++++
 7 files changed, 201 insertions(+)
## 7ace6d5 - Add tests and BDD spex for core domain contexts

Date: 2026-02-23 22:51:08 -0500
Author: John Davenport


 test/cassettes/oauth/google_authorize_url.json     |  139 ++
 test/metric_flow/accounts/account_member_test.exs  |  275 ++++
 .../accounts/account_repository_test.exs           |  759 +++++++++++
 test/metric_flow/accounts/account_test.exs         |  229 ++++
 test/metric_flow/accounts/authorization_test.exs   |  265 ++++
 test/metric_flow/accounts_test.exs                 |  801 ++++++++++++
 .../data_sync/data_providers/behaviour_test.exs    |  733 +++++++++++
 .../data_sync/data_providers/facebook_ads_test.exs | 1085 ++++++++++++++++
 .../data_sync/data_providers/google_ads_test.exs   |  790 ++++++++++++
 .../data_providers/google_analytics_test.exs       |  711 +++++++++++
 .../data_sync/data_providers/quick_books_test.exs  | 1339 ++++++++++++++++++++
 test/metric_flow/data_sync/scheduler_test.exs      |  242 ++++
 .../data_sync/sync_history_repository_test.exs     |  830 ++++++++++++
 test/metric_flow/data_sync/sync_history_test.exs   |  665 ++++++++++
 .../data_sync/sync_job_repository_test.exs         |  531 ++++++++
 test/metric_flow/data_sync/sync_job_test.exs       |  529 ++++++++
 test/metric_flow/data_sync/sync_worker_test.exs    |  679 ++++++++++
 test/metric_flow/data_sync_test.exs                |  504 ++++++++
 .../integrations/integration_repository_test.exs   |  647 ++++++++++
 test/metric_flow/integrations/integration_test.exs |  426 +++++++
 .../integrations/providers/behaviour_test.exs      |  213 ++++
 .../integrations/providers/google_test.exs         |  450 +++++++
 test/metric_flow/integrations_test.exs             |  643 ++++++++++
 .../metric_flow/metrics/metric_repository_test.exs |  813 ++++++++++++
 test/metric_flow/metrics/metric_test.exs           |  256 ++++
 test/metric_flow/metrics_test.exs                  |  690 ++++++++++
 test/metric_flow/users/scope_test.exs              |    3 +
 test/metric_flow/users/user_notifier_test.exs      |    3 +
 test/metric_flow/users/user_test.exs               |    3 +
 test/metric_flow/users/user_token_test.exs         |    3 +
 test/metric_flow/users_test.exs                    |   16 +-
 .../controllers/error_html_test.exs                |    2 +-
 .../controllers/error_json_test.exs                |    2 +-
 .../controllers/page_controller_test.exs           |    2 +-
 .../controllers/user_session_controller_test.exs   |    4 +-
 .../live/account_live/members_test.exs             |  400 ++++++
 .../live/account_live/settings_test.exs            |  611 +++++++++
 .../live/integration_live/connect_test.exs         |  481 +++++++
 .../live/user_live/confirmation_test.exs           |   29 +-
 test/metric_flow_web/live/user_live/login_test.exs |    4 +-
 .../live/user_live/registration_test.exs           |   13 +-
 .../live/user_live/settings_test.exs               |    4 +-
 test/metric_flow_web/user_auth_test.exs            |    4 +-
 test/smoke_test.exs                                |    2 +-
 ...r_can_register_with_email_and_password_spex.exs |   33 +
 ..._is_required_before_account_activation_spex.exs |   71 ++
 ...te_an_account_name_during_registration_spex.exs |   74 ++
 ...d_during_registration_client_or_agency_spex.exs |   83 ++
 ...comes_the_originator_and_default_owner_spex.exs |  105 ++
 ...ged_in_and_directed_to_onboarding_flow_spex.exs |  124 ++
 ...tes_email_format_and_password_strength_spex.exs |  101 ++
 ..._are_rejected_with_clear_error_message_spex.exs |   89 ++
 ...ser_can_log_in_with_email_and_password_spex.exs |   64 +
 ...gin_attempts_show_clear_error_messages_spex.exs |   89 ++
 ...r_session_persists_across_browser_tabs_spex.exs |   68 +
 ...on_3952_user_can_log_out_from_any_page_spex.exs |   93 ++
 ...sions_expire_after_a_reasonable_period_spex.exs |   77 ++
 ...member_me_option_for_extended_sessions_spex.exs |   83 ++
 ...nvite_users_to_their_account_via_email_spex.exs |   80 ++
 ...h_user_has_their_own_login_credentials_spex.exs |  138 ++
 ..._owner_admin_account_manager_read-only_spex.exs |   71 ++
 ..._owners_only_admins_can_add_admins_etc_spex.exs |  114 ++
 ...their_account_with_their_access_levels_spex.exs |   82 ++
 ...or_admin_can_modify_user_access_levels_spex.exs |   65 +
 ...dmin_can_remove_users_from_the_account_spex.exs |  103 ++
 ...same_data_with_account-level_isolation_spex.exs |  106 ++
 ...all_users_with_access_to_their_account_spex.exs |   82 ++
 ...nd_whether_they_are_account_originator_spex.exs |  134 ++
 ...el_to_upgrade_or_downgrade_permissions_spex.exs |  124 ++
 ...t_can_revoke_a_user_access_at_any_time_spex.exs |   94 ++
 ...tely_loses_ability_to_view_client_data_spex.exs |  154 +++
 ...ith_timestamp_and_user_who_made_change_spex.exs |   86 ++
 ...oked_only_ownership_can_be_transferred_spex.exs |  118 ++
 ...ogle_ads_facebook_ads_google_analytics_spex.exs |   95 ++
 ...r_new_tab_with_platform_authentication_spex.exs |   88 ++
 ..._redirected_back_to_platform_selection_spex.exs |   90 ++
 ...erties_to_sync_from_connected_platform_spex.exs |  104 ++
 ...counts_later_without_re-authenticating_spex.exs |   65 +
 ...only_after_successful_oauth_completion_spex.exs |   71 ++
 ...ntegration_is_active_and_ready_to_sync_spex.exs |   78 ++
 ...uth_attempts_show_clear_error_messages_spex.exs |   89 ++
 ...ount_and_is_not_transferable_to_agency_spex.exs |  101 ++
 ...d_integrations_marketing_and_financial_spex.exs |  117 ++
 ...rm_name_connected_date_and_sync_status_spex.exs |   70 +
 ...unts_are_selected_for_each_integration_spex.exs |   70 +
 ...ted_accounts_without_re-authenticating_spex.exs |   75 ++
 ...an_disconnect_or_remove_an_integration_spex.exs |   85 ++
 ..._will_remain_but_no_new_data_will_sync_spex.exs |   93 ++
 ...ect_a_previously_disconnected_platform_spex.exs |   76 ++
 ...niformly_with_no_special_quickbooks_ui_spex.exs |   72 ++
 ..._role_can_access_delete_account_option_spex.exs |  101 ++
 ...account_they_originated_only_owner_can_spex.exs |   96 ++
 ...onfirmation_with_account_name_typed_in_spex.exs |   60 +
 ...equires_password_re-entry_for_security_spex.exs |   86 ++
 ...deletion_is_permanent_and_irreversible_spex.exs |   50 +
 ...s_removed_metrics_reports_integrations_spex.exs |   87 ++
 ...ess_grants_to_this_account_are_revoked_spex.exs |  115 ++
 ...ives_confirmation_email_after_deletion_spex.exs |   65 +
 ..._and_other_roles_cannot_delete_account_spex.exs |  126 ++
 test/support/conn_case.ex                          |   16 +-
 test/support/data_case.ex                          |   14 +-
 test/support/fixtures/users_fixtures.ex            |    6 +-
 test/{spex => support}/metric_flow_spex.ex         |    2 +-
 test/support/metric_flow_test_boundary.ex          |    6 +-
 test/support/plug_store.ex                         |   84 ++
 test/support/shared_givens.ex                      |   96 ++
 106 files changed, 21920 insertions(+), 64 deletions(-)
## 5e40ff1 - Implement core domain contexts: Accounts, Integrations, Metrics, and DataSync

Date: 2026-02-23 22:50:59 -0500
Author: John Davenport


 .env.example                                       |  24 +
 .gitignore                                         |   9 +
 config/runtime.exs                                 |  24 +-
 config/test.exs                                    |  27 +-
 docs/google-ads-api-basic-access-application.md    |  92 ++++
 lib/metric_flow.ex                                 |  19 +-
 lib/metric_flow/accounts.ex                        |  77 +++
 lib/metric_flow/accounts/account.ex                |  51 ++
 lib/metric_flow/accounts/account_member.ex         |  68 +++
 lib/metric_flow/accounts/account_repository.ex     | 295 ++++++++++
 lib/metric_flow/accounts/authorization.ex          | 100 ++++
 lib/metric_flow/data_sync.ex                       | 180 +++++++
 .../data_sync/data_providers/behaviour.ex          |  75 +++
 .../data_sync/data_providers/facebook_ads.ex       | 311 +++++++++++
 .../data_sync/data_providers/google_ads.ex         | 380 +++++++++++++
 .../data_sync/data_providers/google_analytics.ex   | 344 ++++++++++++
 .../data_sync/data_providers/quick_books.ex        | 318 +++++++++++
 lib/metric_flow/data_sync/scheduler.ex             |  79 +++
 lib/metric_flow/data_sync/sync_history.ex          | 112 ++++
 .../data_sync/sync_history_repository.ex           | 124 +++++
 lib/metric_flow/data_sync/sync_job.ex              | 111 ++++
 lib/metric_flow/data_sync/sync_job_repository.ex   | 184 +++++++
 lib/metric_flow/data_sync/sync_worker.ex           | 331 ++++++++++++
 lib/metric_flow/encrypted/binary.ex                |  12 +
 lib/metric_flow/integrations.ex                    | 198 +++++++
 lib/metric_flow/integrations/integration.ex        | 120 +++++
 .../integrations/integration_repository.ex         | 204 +++++++
 .../integrations/providers/behaviour.ex            |  43 ++
 lib/metric_flow/integrations/providers/google.ex   | 111 ++++
 lib/metric_flow/metrics.ex                         |  32 ++
 lib/metric_flow/metrics/metric.ex                  |  86 +++
 lib/metric_flow/metrics/metric_repository.ex       | 305 +++++++++++
 lib/metric_flow/users.ex                           |  26 +-
 lib/metric_flow/users/user.ex                      |  22 +
 lib/metric_flow_web.ex                             |   2 +-
 .../controllers/integration_callback_controller.ex |  29 +
 lib/metric_flow_web/live/account_live/index.ex     |  59 ++
 lib/metric_flow_web/live/account_live/members.ex   | 393 ++++++++++++++
 lib/metric_flow_web/live/account_live/settings.ex  | 454 ++++++++++++++++
 .../live/integration_live/connect.ex               | 600 +++++++++++++++++++++
 lib/metric_flow_web/live/integration_live/index.ex | 149 +++++
 lib/metric_flow_web/live/onboarding_live.ex        |  24 +
 lib/metric_flow_web/live/user_live/confirmation.ex |  36 +-
 lib/metric_flow_web/live/user_live/registration.ex | 126 +++--
 lib/metric_flow_web/router.ex                      |  14 +
 mix.exs                                            |   4 +-
 ...0223154021_add_registration_fields_to_users.exs |  10 +
 ...3170447_create_accounts_and_account_members.exs |  28 +
 .../20260223200000_create_integrations.exs         |  20 +
 .../migrations/20260223210000_create_metrics.exs   |  21 +
 .../migrations/20260223220000_create_sync_jobs.exs |  21 +
 .../20260223230000_create_sync_history.exs         |  24 +
 52 files changed, 6440 insertions(+), 68 deletions(-)
## f2477ab - Update CodeMySpec specs, architecture, and status for core domain contexts

Date: 2026-02-23 22:50:45 -0500
Author: John Davenport


 .code_my_spec/architecture/decisions.md            |   2 +-
 .../architecture/decisions/email_provider.md       |  42 +-
 .code_my_spec/architecture/dependency_graph.mmd    |  10 +-
 .code_my_spec/architecture/namespace_hierarchy.md  |  34 +-
 .code_my_spec/architecture/overview.md             |  33 +-
 .code_my_spec/config.yml                           |  10 +-
 .code_my_spec/knowledge/email_provider/setup.md    | 277 ++---------
 .../write_bdd_specs.md                             |  22 +
 .../session.json                                   |   1 +
 .../write_bdd_specs.md                             |  22 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../write_bdd_specs.md                             |  22 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../session.json                                   |   1 +
 .../subagent_prompts/bdd_specs_story_425.md        | 474 ++++++++++++++++++
 .../subagent_prompts/bdd_specs_story_426.md        | 530 +++++++++++++++++++++
 .../write_bdd_specs.md                             |  22 +
 .code_my_spec/spec/metric_flow/accounts.spec.md    | 353 +++++++++++++-
 .../spec/metric_flow/accounts/account.spec.md      |  88 ++++
 .../metric_flow/accounts/account_member.spec.md    |  81 ++++
 .../accounts/account_repository.spec.md            | 246 ++++++++++
 .../metric_flow/accounts/authorization.spec.md     |  69 +++
 .../spec/metric_flow/accounts/design_review.md     |  32 ++
 .../spec/metric_flow/integrations.spec.md          |   4 -
 .../spec/metric_flow/integrations/design_review.md |   4 +-
 .../integrations/providers/git_hub.spec.md         |  96 ----
 .code_my_spec/spec/metric_flow/metrics.spec.md     |  43 +-
 .../spec/metric_flow/metrics/design_review.md      |  37 ++
 .../spec/metric_flow/metrics/metric.spec.md        |  62 +++
 .../metric_flow/metrics/metric_repository.spec.md  | 214 +++++++++
 .code_my_spec/spec/metric_flow/users.spec.md       | 328 ++++++++++++-
 .../spec/metric_flow/users/design_review.md        |  36 ++
 .code_my_spec/spec/metric_flow/users/scope.spec.md |  35 ++
 .code_my_spec/spec/metric_flow/users/user.spec.md  |  97 ++++
 .../spec/metric_flow/users/user_notifier.spec.md   |  49 ++
 .../spec/metric_flow/users/user_token.spec.md      | 116 +++++
 .../metric_flow_web/account_live/index.spec.md     |   4 +-
 .../metric_flow_web/account_live/members.spec.md   | 146 ++----
 .../metric_flow_web/account_live/settings.spec.md  | 177 ++-----
 .../integration_live/connect.spec.md               |  78 ++-
 .../metric_flow_web/user_live/registration.spec.md |  41 +-
 .code_my_spec/status/implementation_status.json    |   1 +
 .code_my_spec/status/metric_flow.md                |  11 +-
 .code_my_spec/status/metric_flow/accounts.md       |  50 +-
 .../metric_flow/agencies/agencies_repository.md    |  11 +
 .../metric_flow/agencies/auto_enrollment_rule.md   |  11 +
 .../metric_flow/agencies/white_label_config.md     |  11 +
 .../status/metric_flow/ai/chat_message.md          |   8 +
 .../status/metric_flow/ai/chat_session.md          |   8 +
 .code_my_spec/status/metric_flow/ai/insight.md     |   8 +
 .../status/metric_flow/ai/insights_generator.md    |  11 +
 .code_my_spec/status/metric_flow/ai/llm_client.md  |  11 +
 .../status/metric_flow/ai/report_generator.md      |  11 +
 .../status/metric_flow/ai/suggestion_feedback.md   |   8 +
 .../metric_flow/correlations/correlation_job.md    |   8 +
 .../metric_flow/correlations/correlation_result.md |   8 +
 .../metric_flow/correlations/correlation_worker.md |  11 +
 .../correlations/correlations_repository.md        |  11 +
 .../status/metric_flow/dashboards/dashboard.md     |   8 +
 .../dashboards/dashboard_visualization.md          |   8 +
 .../dashboards/dashboards_repository.md            |  11 +
 .../status/metric_flow/dashboards/visualization.md |   8 +
 .../dashboards/visualizations_repository.md        |  11 +
 .code_my_spec/status/metric_flow/data_sync.md      |  64 +--
 .../data_sync/data_providers/behaviour.md          |  11 +
 .../data_sync/data_providers/facebook_ads.md       |  11 +
 .../data_sync/data_providers/google_ads.md         |  11 +
 .../data_sync/data_providers/google_analytics.md   |  11 +
 .../data_sync/data_providers/quick_books.md        |  11 +
 .../metric_flow/data_sync/develop_context.md       |  84 ++++
 .../data_sync/metricflow_datasync_code.md          |  76 +++
 ...icflow_datasync_dataproviders_behaviour_code.md |  76 +++
 ...icflow_datasync_dataproviders_behaviour_test.md |  64 +++
 ...flow_datasync_dataproviders_facebookads_code.md |  76 +++
 ...flow_datasync_dataproviders_facebookads_test.md |  64 +++
 ...icflow_datasync_dataproviders_googleads_code.md |  76 +++
 ...icflow_datasync_dataproviders_googleads_test.md |  64 +++
 ..._datasync_dataproviders_googleanalytics_code.md |  76 +++
 ..._datasync_dataproviders_googleanalytics_test.md |  64 +++
 ...cflow_datasync_dataproviders_quickbooks_code.md |  76 +++
 ...cflow_datasync_dataproviders_quickbooks_test.md |  64 +++
 .../metricflow_datasync_scheduler_code.md          |  76 +++
 .../metricflow_datasync_scheduler_test.md          |  64 +++
 .../metricflow_datasync_synchistory_code.md        |  76 +++
 .../metricflow_datasync_synchistory_test.md        |  64 +++
 ...tricflow_datasync_synchistoryrepository_code.md |  76 +++
 ...tricflow_datasync_synchistoryrepository_test.md |  64 +++
 .../data_sync/metricflow_datasync_syncjob_code.md  |  76 +++
 .../data_sync/metricflow_datasync_syncjob_test.md  |  64 +++
 .../metricflow_datasync_syncjobrepository_code.md  |  76 +++
 .../metricflow_datasync_syncjobrepository_test.md  |  64 +++
 .../metricflow_datasync_syncworker_code.md         |  76 +++
 .../metricflow_datasync_syncworker_test.md         |  64 +++
 .../data_sync/metricflow_datasync_test.md          |  64 +++
 .../status/metric_flow/data_sync/scheduler.md      |  11 +
 .../status/metric_flow/data_sync/sync_history.md   |  11 +
 .../data_sync/sync_history_repository.md           |  11 +
 .../status/metric_flow/data_sync/sync_job.md       |  11 +
 .../metric_flow/data_sync/sync_job_repository.md   |  11 +
 .../status/metric_flow/data_sync/sync_worker.md    |  11 +
 .code_my_spec/status/metric_flow/encrypted.md      |  17 +
 .code_my_spec/status/metric_flow/integrations.md   |  30 +-
 .../metric_flow/integrations/develop_context.md    |   8 -
 .code_my_spec/status/metric_flow/metrics.md        |  20 +-
 .code_my_spec/status/metric_flow/users.md          |  30 +-
 .code_my_spec/status/metric_flow_web.md            |  40 +-
 .../status/metric_flow_web/account_live.md         |  37 ++
 .../status/metric_flow_web/account_live/index.md   |  10 +-
 .../status/metric_flow_web/account_live/members.md |  10 +-
 .../metric_flow_web/account_live/settings.md       |  10 +-
 .../status/metric_flow_web/agency_live.md          |  17 +
 .code_my_spec/status/metric_flow_web/ai_live.md    |  37 ++
 .../status/metric_flow_web/correlation_live.md     |  27 ++
 .../status/metric_flow_web/dashboard_live.md       |  37 ++
 .../status/metric_flow_web/integration_live.md     |  37 ++
 .../metric_flow_web/integration_live/connect.md    |   6 +-
 .../metric_flow_web/integration_live/index.md      |   2 +-
 .../status/metric_flow_web/invitation_live.md      |  27 ++
 .../status/metric_flow_web/onboarding_live.md      |  11 +
 .code_my_spec/status/metric_flow_web/user_live.md  |  47 ++
 .../metric_flow_web/user_live/registration.md      |   2 +-
 .../status/metric_flow_web/visualization_live.md   |  17 +
 125 files changed, 5784 insertions(+), 831 deletions(-)
## c288e22 - Add CodeMySpec specs, Boundary enforcement, and architecture review fixes

Date: 2026-02-23 09:54:01 -0500
Author: John Davenport


 .code_my_spec/AGENTS.md                            | 133 +++
 .code_my_spec/architecture/decisions.md            |  29 +
 .../decisions/authorization_strategy.md            |  46 ++
 .../decisions/background_job_processing.md         | 245 ++++++
 .../architecture/decisions/bdd-testing.md          |  65 ++
 .../architecture/decisions/caching_strategy.md     | 348 ++++++++
 .../architecture/decisions/charting_library.md     | 318 +++++++
 .../architecture/decisions/correlation_engine.md   | 261 ++++++
 .../decisions/css_component_library.md             |  95 +++
 .code_my_spec/architecture/decisions/daisyui.md    |  35 +
 .../architecture/decisions/data_provider_apis.md   | 183 +++++
 .code_my_spec/architecture/decisions/deployment.md | 185 +++++
 .code_my_spec/architecture/decisions/dotenvy.md    |  71 ++
 .../architecture/decisions/e2e_testing.md          | 147 ++++
 .code_my_spec/architecture/decisions/elixir.md     |  61 ++
 .../architecture/decisions/email_provider.md       | 223 +++++
 .code_my_spec/architecture/decisions/exvcr.md      |  45 +
 .../architecture/decisions/file_storage.md         | 282 +++++++
 .code_my_spec/architecture/decisions/liveview.md   |  69 ++
 .../architecture/decisions/llm_provider.md         | 251 ++++++
 .../decisions/monitoring_observability.md          | 456 +++++++++++
 .code_my_spec/architecture/decisions/ngrok.md      |  81 ++
 .../architecture/decisions/oauth_token_refresh.md  | 269 ++++++
 .code_my_spec/architecture/decisions/phoenix.md    |  50 ++
 .../architecture/decisions/phx-gen-auth.md         |  60 ++
 .../architecture/decisions/report_export.md        | 304 +++++++
 .code_my_spec/architecture/decisions/tailwind.md   |  53 ++
 .code_my_spec/architecture/dependency_graph.mmd    |  60 ++
 .code_my_spec/architecture/namespace_hierarchy.md  |  97 +++
 .code_my_spec/architecture/overview.md             | 295 +++++++
 .code_my_spec/architecture/proposal.md             | 334 ++++++++
 .code_my_spec/design/design_system.html            | 738 +++++++++++++++++
 .../knowledge/authorization_strategy/setup.md      | 445 ++++++++++
 .../knowledge/background_job_processing/setup.md   | 669 +++++++++++++++
 .code_my_spec/knowledge/caching_strategy/setup.md  | 845 +++++++++++++++++++
 .code_my_spec/knowledge/charting_library/setup.md  | 713 ++++++++++++++++
 .../knowledge/correlation_engine/approaches.md     | 433 ++++++++++
 .../correlation_engine/implementation_patterns.md  | 297 +++++++
 .../knowledge/css_component_library/setup.md       | 708 ++++++++++++++++
 .../data_provider_apis/error_normalization.md      | 206 +++++
 .../knowledge/data_provider_apis/facebook_ads.md   | 304 +++++++
 .../knowledge/data_provider_apis/google_ads.md     | 292 +++++++
 .../data_provider_apis/google_analytics.md         | 255 ++++++
 .../knowledge/data_provider_apis/quickbooks.md     | 387 +++++++++
 .../knowledge/data_provider_apis/req_patterns.md   | 240 ++++++
 .../knowledge/data_provider_apis/setup.md          | 909 +++++++++++++++++++++
 .code_my_spec/knowledge/deployment/setup.md        | 737 +++++++++++++++++
 .code_my_spec/knowledge/e2e_testing/setup.md       | 499 +++++++++++
 .code_my_spec/knowledge/email_provider/setup.md    | 442 ++++++++++
 .code_my_spec/knowledge/file_storage/setup.md      | 508 ++++++++++++
 .../knowledge/llm_integration/data_in_context.md   | 107 +++
 .../knowledge/llm_integration/elixir_libraries.md  | 240 ++++++
 .../knowledge/llm_integration/overview.md          | 116 +++
 .../knowledge/llm_integration/providers.md         | 120 +++
 .code_my_spec/knowledge/llm_provider/models.md     | 111 +++
 .code_my_spec/knowledge/llm_provider/setup.md      | 163 ++++
 .code_my_spec/knowledge/llm_provider/streaming.md  | 180 ++++
 .../knowledge/llm_provider/structured_output.md    | 250 ++++++
 .code_my_spec/knowledge/llm_provider/testing.md    | 242 ++++++
 .../knowledge/monitoring_observability/setup.md    | 768 +++++++++++++++++
 .../knowledge/oauth_token_refresh/setup.md         | 384 +++++++++
 .code_my_spec/knowledge/report_export/setup.md     | 788 ++++++++++++++++++
 .code_my_spec/rules/collaboration_guidelines.md    |  12 +
 .code_my_spec/rules/context_design.md              |  16 +
 .code_my_spec/rules/documentation_writing.md       | 129 +++
 .code_my_spec/rules/elixir.md                      |  43 +
 .code_my_spec/rules/elixir_design.md               |  21 +
 .code_my_spec/rules/elixir_test.md                 |  18 +
 .code_my_spec/rules/feature_page_writing.md        |  51 ++
 .code_my_spec/rules/live_context_design.md         |  21 +
 .code_my_spec/rules/liveview.md                    |  57 ++
 .code_my_spec/rules/liveview_component_design.md   |  41 +
 .code_my_spec/rules/liveview_design.md             |  47 ++
 .code_my_spec/rules/liveview_forms.md              |  37 +
 .code_my_spec/rules/repository.md                  |  10 +
 .code_my_spec/rules/repository_design.md           |  79 ++
 .code_my_spec/rules/repository_test.md             | 100 +++
 .code_my_spec/rules/schema.md                      |  16 +
 .code_my_spec/rules/schema_design.md               |  13 +
 .code_my_spec/rules/tool_design.md                 | 107 +++
 .code_my_spec/rules/tools.md                       |   6 +
 .code_my_spec/spec/metric_flow/accounts.spec.md    |  14 +
 .code_my_spec/spec/metric_flow/agencies.spec.md    | 275 +++++++
 .../agencies/agencies_repository.spec.md           | 373 +++++++++
 .../agencies/auto_enrollment_rule.spec.md          |  70 ++
 .../agencies/white_label_config.spec.md            |  83 ++
 .code_my_spec/spec/metric_flow/ai.spec.md          |  16 +
 .../spec/metric_flow/ai/chat_message.spec.md       |  14 +
 .../spec/metric_flow/ai/chat_session.spec.md       |  14 +
 .code_my_spec/spec/metric_flow/ai/insight.spec.md  |  14 +
 .../spec/metric_flow/ai/insights_generator.spec.md |  14 +
 .../spec/metric_flow/ai/llm_client.spec.md         |  14 +
 .../spec/metric_flow/ai/report_generator.spec.md   |  14 +
 .../metric_flow/ai/suggestion_feedback.spec.md     |  14 +
 .../spec/metric_flow/correlations.spec.md          |  14 +
 .../correlations/correlation_job.spec.md           |  14 +
 .../correlations/correlation_result.spec.md        |  14 +
 .../correlations/correlation_worker.spec.md        |  14 +
 .../correlations/correlations_repository.spec.md   |  14 +
 .code_my_spec/spec/metric_flow/dashboards.spec.md  |  14 +
 .../spec/metric_flow/dashboards/dashboard.spec.md  |  14 +
 .../dashboards/dashboard_visualization.spec.md     |  14 +
 .../dashboards/dashboards_repository.spec.md       |  14 +
 .../metric_flow/dashboards/visualization.spec.md   |  14 +
 .../dashboards/visualizations_repository.spec.md   |  14 +
 .code_my_spec/spec/metric_flow/data_sync.spec.md   | 199 +++++
 .../data_sync/data_providers/behaviour.spec.md     | 110 +++
 .../data_sync/data_providers/facebook_ads.spec.md  | 146 ++++
 .../data_sync/data_providers/google_ads.spec.md    | 128 +++
 .../data_providers/google_analytics.spec.md        | 106 +++
 .../data_sync/data_providers/quick_books.spec.md   | 146 ++++
 .../spec/metric_flow/data_sync/design_review.md    |  32 +
 .../spec/metric_flow/data_sync/scheduler.spec.md   |  62 ++
 .../metric_flow/data_sync/sync_history.spec.md     | 124 +++
 .../data_sync/sync_history_repository.spec.md      | 118 +++
 .../spec/metric_flow/data_sync/sync_job.spec.md    | 134 +++
 .../data_sync/sync_job_repository.spec.md          | 146 ++++
 .../spec/metric_flow/data_sync/sync_worker.spec.md |  99 +++
 .../spec/metric_flow/integrations.spec.md          | 150 ++++
 .../spec/metric_flow/integrations/design_review.md |  31 +
 .../metric_flow/integrations/integration.spec.md   | 114 +++
 .../integrations/integration_repository.spec.md    | 208 +++++
 .../integrations/providers/behaviour.spec.md       |  79 ++
 .../integrations/providers/git_hub.spec.md         |  96 +++
 .../integrations/providers/google.spec.md          | 101 +++
 .code_my_spec/spec/metric_flow/invitations.spec.md |  14 +
 .code_my_spec/spec/metric_flow/metrics.spec.md     | 201 +++++
 .../spec/metric_flow/metrics/metric.spec.md        |   3 +
 .../metric_flow/metrics/metric_repository.spec.md  |   3 +
 .code_my_spec/spec/metric_flow/users.spec.md       |  14 +
 .../metric_flow_web/account_live/index.spec.md     | 110 +++
 .../metric_flow_web/account_live/members.spec.md   | 135 +++
 .../metric_flow_web/account_live/settings.spec.md  | 159 ++++
 .../metric_flow_web/agency_live/settings.spec.md   |  14 +
 .../spec/metric_flow_web/ai_live/chat.spec.md      |  14 +
 .../spec/metric_flow_web/ai_live/insights.spec.md  |  14 +
 .../ai_live/report_generator.spec.md               |  14 +
 .../metric_flow_web/correlation_live/goals.spec.md |  14 +
 .../metric_flow_web/correlation_live/index.spec.md |  14 +
 .../metric_flow_web/dashboard_live/editor.spec.md  |  14 +
 .../metric_flow_web/dashboard_live/index.spec.md   |  14 +
 .../metric_flow_web/dashboard_live/show.spec.md    |  14 +
 .../integration_live/connect.spec.md               |  14 +
 .../metric_flow_web/integration_live/index.spec.md |  15 +
 .../integration_live/sync_history.spec.md          |  14 +
 .../metric_flow_web/invitation_live/accept.spec.md |  14 +
 .../metric_flow_web/invitation_live/send.spec.md   |  14 +
 .../spec/metric_flow_web/user_live/login.spec.md   |  14 +
 .../metric_flow_web/user_live/registration.spec.md |  14 +
 .../metric_flow_web/user_live/settings.spec.md     |  14 +
 .../visualization_live/editor.spec.md              |  14 +
 .code_my_spec/status/metric_flow.md                |  22 +
 .code_my_spec/status/metric_flow/accounts.md       |  13 +
 .code_my_spec/status/metric_flow/agencies.md       |  43 +
 .../status/metric_flow/agencies/develop_context.md |  44 +
 ...w_agencies_agenciesrepository_component_spec.md | 118 +++
 ...w_agencies_autoenrollmentrule_component_spec.md | 118 +++
 .../agencies/metricflow_agencies_context_spec.md   | 146 ++++
 ...low_agencies_whitelabelconfig_component_spec.md | 118 +++
 .code_my_spec/status/metric_flow/ai.md             |  71 ++
 .code_my_spec/status/metric_flow/application.md    |  13 +
 .code_my_spec/status/metric_flow/correlations.md   |  47 ++
 .code_my_spec/status/metric_flow/dashboards.md     |  54 ++
 .code_my_spec/status/metric_flow/data_sync.md      | 123 +++
 .../status/metric_flow/encrypted/binary.md         |  11 +
 .code_my_spec/status/metric_flow/infrastructure.md |  41 +
 .code_my_spec/status/metric_flow/integrations.md   |  63 ++
 .../metric_flow/integrations/develop_context.md    |   8 +
 .code_my_spec/status/metric_flow/invitations.md    |  13 +
 .code_my_spec/status/metric_flow/metrics.md        |  33 +
 .../status/metric_flow/user_preferences.md         |  21 +
 .code_my_spec/status/metric_flow/users.md          |  53 ++
 .code_my_spec/status/metric_flow/vault.md          |  11 +
 .code_my_spec/status/metric_flow_web.md            |  43 +
 .../status/metric_flow_web/account_live/index.md   |  11 +
 .../status/metric_flow_web/account_live/members.md |  11 +
 .../metric_flow_web/account_live/settings.md       |  11 +
 .../status/metric_flow_web/agency_live/clients.md  |  10 +
 .../status/metric_flow_web/agency_live/settings.md |  11 +
 .../status/metric_flow_web/agency_live/team.md     |  10 +
 .../status/metric_flow_web/ai_live/chat.md         |  11 +
 .../status/metric_flow_web/ai_live/insights.md     |  11 +
 .../metric_flow_web/ai_live/report_generator.md    |  11 +
 .../status/metric_flow_web/application.md          |  11 +
 .../status/metric_flow_web/core_components.md      |  11 +
 .../metric_flow_web/correlation_live/goals.md      |  11 +
 .../metric_flow_web/correlation_live/index.md      |  11 +
 .../metric_flow_web/dashboard_live/editor.md       |  11 +
 .../status/metric_flow_web/dashboard_live/index.md |  11 +
 .../status/metric_flow_web/dashboard_live/show.md  |  11 +
 .code_my_spec/status/metric_flow_web/endpoint.md   |  13 +
 .code_my_spec/status/metric_flow_web/error_html.md |  11 +
 .code_my_spec/status/metric_flow_web/error_json.md |  11 +
 .code_my_spec/status/metric_flow_web/gettext.md    |  13 +
 .../integration_callback_controller.md             |  11 +
 .../metric_flow_web/integration_live/connect.md    |  11 +
 .../metric_flow_web/integration_live/index.md      |  11 +
 .../integration_live/sync_history.md               |  11 +
 .../metric_flow_web/invitation_live/accept.md      |  11 +
 .../status/metric_flow_web/invitation_live/send.md |  11 +
 .code_my_spec/status/metric_flow_web/layouts.md    |  11 +
 .../status/metric_flow_web/page_controller.md      |  11 +
 .code_my_spec/status/metric_flow_web/page_html.md  |  11 +
 .code_my_spec/status/metric_flow_web/prom_ex.md    |  11 +
 .code_my_spec/status/metric_flow_web/router.md     |  13 +
 .code_my_spec/status/metric_flow_web/telemetry.md  |  13 +
 .code_my_spec/status/metric_flow_web/user_auth.md  |  11 +
 .../metric_flow_web/user_live/confirmation.md      |  11 +
 .../status/metric_flow_web/user_live/login.md      |  11 +
 .../metric_flow_web/user_live/registration.md      |  11 +
 .../status/metric_flow_web/user_live/settings.md   |  11 +
 .../metric_flow_web/user_session_controller.md     |  11 +
 .../metric_flow_web/visualization_live/editor.md   |  11 +
 .gitignore                                         |   4 +
 .gitmodules                                        |   3 -
 CLAUDE.md                                          |  19 +
 docs                                               |   1 -
 lib/metric_flow.ex                                 |   5 +
 lib/metric_flow/users.ex                           |   2 +
 lib/metric_flow_web.ex                             |   2 +
 .../application.ex                                 |   2 +-
 mix.exs                                            |   4 +-
 mix.lock                                           |   2 +-
 223 files changed, 25073 insertions(+), 8 deletions(-)
## c4bfd3f - Bootstrap decided libraries into supervision tree

Date: 2026-02-22 12:49:27 -0500
Author: John Davenport


 docs                                               |  2 +-
 lib/metric_flow/application.ex                     |  6 ++-
 lib/metric_flow/vault.ex                           |  6 +++
 lib/metric_flow_web/prom_ex.ex                     | 38 +++++++++++++
 lib/metric_flow_web/router.ex                      |  7 ++-
 .../20260222000001_add_oban_jobs_table.exs         | 11 ++++
 test/smoke_test.exs                                | 63 ++++++++++++++++++++++
 7 files changed, 129 insertions(+), 4 deletions(-)
## 1f39bff - Add CodeMySpec dependencies and BDD spex configuration

Date: 2026-02-22 12:31:37 -0500
Author: John Davenport


 mix.exs                                   | 17 +++++++++++++----
 mix.lock                                  |  1 +
 test/spex/metric_flow_spex.ex             |  4 ++++
 test/support/metric_flow_test_boundary.ex |  4 ++++
 4 files changed, 22 insertions(+), 4 deletions(-)
## 51772fc - Add technical strategy dependencies and configuration

Date: 2026-02-22 12:21:43 -0500
Author: John Davenport


 .code_my_spec/config.yml |  16 +++++--
 config/config.exs        |  29 +++++++++++++
 config/runtime.exs       | 107 +++++++++++++++++++++++++----------------------
 config/test.exs          |   6 +++
 mix.exs                  |  27 ++++++++++++
 mix.lock                 |  43 +++++++++++++++++++
 6 files changed, 176 insertions(+), 52 deletions(-)
## 6e00ca8 - Add docs as git submodule

Date: 2026-01-30 23:15:15 -0500
Author: John Davenport


 .gitmodules | 3 +++
 docs        | 1 +
 2 files changed, 4 insertions(+)
## c78a330 - cms setup and phx gen auth

Date: 2026-01-30 22:57:53 -0500
Author: John Davenport


 .code_my_spec/config.yml                           |   7 +
 AGENTS.md                                          |  61 ++++
 config/config.exs                                  |  13 +
 config/test.exs                                    |   3 +
 lib/metric_flow/users.ex                           | 297 +++++++++++++++
 lib/metric_flow/users/scope.ex                     |  33 ++
 lib/metric_flow/users/user.ex                      | 132 +++++++
 lib/metric_flow/users/user_notifier.ex             |  84 +++++
 lib/metric_flow/users/user_token.ex                | 156 ++++++++
 .../components/layouts/root.html.heex              |  20 ++
 .../controllers/user_session_controller.ex         |  67 ++++
 lib/metric_flow_web/live/user_live/confirmation.ex |  94 +++++
 lib/metric_flow_web/live/user_live/login.ex        | 131 +++++++
 lib/metric_flow_web/live/user_live/registration.ex |  88 +++++
 lib/metric_flow_web/live/user_live/settings.ex     | 157 ++++++++
 lib/metric_flow_web/router.ex                      |  31 ++
 lib/metric_flow_web/user_auth.ex                   | 287 +++++++++++++++
 mix.exs                                            |   9 +-
 mix.lock                                           |   9 +
 .../20260131034937_create_users_auth_tables.exs    |  30 ++
 test/metric_flow/users_test.exs                    | 397 +++++++++++++++++++++
 .../controllers/user_session_controller_test.exs   | 147 ++++++++
 .../live/user_live/confirmation_test.exs           | 118 ++++++
 test/metric_flow_web/live/user_live/login_test.exs | 109 ++++++
 .../live/user_live/registration_test.exs           |  82 +++++
 .../live/user_live/settings_test.exs               | 212 +++++++++++
 test/metric_flow_web/user_auth_test.exs            | 390 ++++++++++++++++++++
 test/support/conn_case.ex                          |  41 +++
 test/support/fixtures/users_fixtures.ex            |  89 +++++
 29 files changed, 3293 insertions(+), 1 deletion(-)
## b259e2c - initial commit

Date: 2026-01-30 22:17:04 -0500
Author: John Davenport


 .formatter.exs                                     |    6 +
 .gitignore                                         |   37 +
 AGENTS.md                                          |  334 +++++++
 README.md                                          |   18 +
 assets/css/app.css                                 |  105 ++
 assets/js/app.js                                   |   83 ++
 assets/tsconfig.json                               |   32 +
 assets/vendor/daisyui-theme.js                     |  124 +++
 assets/vendor/daisyui.js                           | 1031 ++++++++++++++++++++
 assets/vendor/heroicons.js                         |   43 +
 assets/vendor/topbar.js                            |  138 +++
 config/config.exs                                  |   65 ++
 config/dev.exs                                     |   88 ++
 config/prod.exs                                    |   21 +
 config/runtime.exs                                 |  119 +++
 config/test.exs                                    |   37 +
 lib/metric_flow.ex                                 |    9 +
 lib/metric_flow/application.ex                     |   34 +
 lib/metric_flow/mailer.ex                          |    3 +
 lib/metric_flow/repo.ex                            |    5 +
 lib/metric_flow_web.ex                             |  114 +++
 lib/metric_flow_web/components/core_components.ex  |  472 +++++++++
 lib/metric_flow_web/components/layouts.ex          |  154 +++
 .../components/layouts/root.html.heex              |   36 +
 lib/metric_flow_web/controllers/error_html.ex      |   24 +
 lib/metric_flow_web/controllers/error_json.ex      |   21 +
 lib/metric_flow_web/controllers/page_controller.ex |    7 +
 lib/metric_flow_web/controllers/page_html.ex       |   10 +
 .../controllers/page_html/home.html.heex           |  202 ++++
 lib/metric_flow_web/endpoint.ex                    |   54 +
 lib/metric_flow_web/gettext.ex                     |   25 +
 lib/metric_flow_web/router.ex                      |   44 +
 lib/metric_flow_web/telemetry.ex                   |   93 ++
 mix.exs                                            |   94 ++
 mix.lock                                           |   46 +
 priv/gettext/en/LC_MESSAGES/errors.po              |  112 +++
 priv/gettext/errors.pot                            |  109 +++
 priv/repo/migrations/.formatter.exs                |    4 +
 priv/repo/seeds.exs                                |   11 +
 priv/static/favicon.ico                            |  Bin 0 -> 152 bytes
 priv/static/images/logo.svg                        |    6 +
 priv/static/robots.txt                             |    5 +
 .../controllers/error_html_test.exs                |   14 +
 .../controllers/error_json_test.exs                |   12 +
 .../controllers/page_controller_test.exs           |    8 +
 test/support/conn_case.ex                          |   38 +
 test/support/data_case.ex                          |   58 ++
 test/test_helper.exs                               |    2 +
 48 files changed, 4107 insertions(+)
