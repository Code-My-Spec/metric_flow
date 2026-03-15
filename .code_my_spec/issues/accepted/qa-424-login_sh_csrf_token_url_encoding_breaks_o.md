# login.sh CSRF token URL-encoding breaks on tokens with single quotes

## Status

resolved

## Severity

medium

## Scope

qa

## Description

The  login.sh  script and  authenticated_curl.sh  both use a Python one-liner to URL-encode the CSRF token by interpolating the raw token value into a shell string: ENCODED_CSRF=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$CSRF'))") When the CSRF token contains a newline or the shell expands it in a way that breaks the Python string literal (e.g., the token wraps onto a new line when echoed), Python raises  SyntaxError: unterminated string literal . This caused  start-qa.sh  to fail during the curl session setup step. The seed data setup succeeded and the QA session was completed using vibium browser automation, which does not depend on the curl login scripts. However, the curl-based auth scripts are broken for any story that requires them. Fix: pipe the token through stdin instead of shell interpolation: ENCODED_CSRF=$(echo -n "$CSRF" | python3 -c "import sys, urllib.parse; print(urllib.parse.quote(sys.stdin.read()))")

## Source

QA Story 424 — `.code_my_spec/qa/424/result.md`

## Resolution

No code change needed. The affected `login.sh` script has already been deprecated and replaced with vibium MCP browser automation (see `.code_my_spec/qa/scripts/login.sh` — exits with deprecation notice). The `authenticated_curl.sh` script no longer exists. No active QA scripts use the broken `urllib.parse.quote('$CSRF')` shell interpolation pattern.

- **Files changed:** none (scripts already deprecated)
- **Verification:** `grep -r "urllib.parse.quote" .code_my_spec/qa/scripts/` returns no matches — the broken pattern exists only in the QA result documentation describing the original bug
