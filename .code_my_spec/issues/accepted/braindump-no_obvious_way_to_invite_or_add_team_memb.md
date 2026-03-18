# No obvious way to invite or add team members from the main UI

## Status

resolved

## Severity

medium

## Scope

app

## Description

There is no clear navigation path for account administrators to invite new members. The /accounts/members page exists with an invite form, but there is no visible link or menu item in the main navigation that leads to team management or member invitations. Users have to know the URL directly. There should be a 'Team' or 'Members' link in the navigation sidebar or account settings that makes it obvious how to add people to the account.

## Source

Braindump import

## Resolution

Added 'Members' navigation link to both mobile and desktop menus in layouts.ex, pointing to /accounts/members. Visible only for authenticated users. All 569 web tests pass.
