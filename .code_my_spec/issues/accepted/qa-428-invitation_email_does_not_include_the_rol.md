# Invitation email does not include the role/access level

## Status

accepted

## Severity

low

## Scope

app

## Description

Per AC4, the invitation should include the client account name and access level. The email subject and body correctly include the account name ("QA Test Account"). However, the email body does not mention the role or access level granted to the recipient. Only the invitation acceptance page (at  /invitations/{token} ) shows the access level. The email text reads: "You have been invited to join QA Test Account on MetricFlow. Click the link below to accept your invitation." — no mention of whether the invitee will be "Admin", "Account Manager", or "Read Only". The acceptance page correctly shows the role ("qa@example.com has invited you to join QA Test Account as a Admin."), so AC4 is partially satisfied. The email itself should also include the access level for the user to make an informed decision before clicking the link. Evidence:  .code_my_spec/qa/428/screenshots/05_ac2_email_content.png ,  .code_my_spec/qa/428/screenshots/06_ac4_mailbox_admin_invite.png

## Source

QA Story 428 — `.code_my_spec/qa/428/result.md`
