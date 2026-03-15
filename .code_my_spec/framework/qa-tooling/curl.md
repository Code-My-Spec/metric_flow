# curl for Autonomous Agents

This skill provides curl patterns optimized for agentic coding environments (Claude Code, Cursor, Codex, etc.) where multiline commands, heredocs, and backslash continuations trigger permission checks and break automation flow.

## CRITICAL: Single-Line Rules

**NEVER use multiline curl commands.** Multiline commands (backslash `\` continuations, heredocs `<<EOF`, pipe chains across lines) trigger permission re-prompts in most agentic tool environments. Every pattern in this file is a single-line command.

**Why this matters:**
- Backslash continuations (`\`) are treated as separate command chunks by permission matchers
- Heredocs (`<<EOF ... EOF`) cannot be pattern-matched by wildcard permission rules like `Bash(curl:*)`
- Multiline commands that get "always allowed" pollute settings files with unparseable junk
- Even `&&` chains spanning multiple lines trigger fresh permission checks

**The fix:** Every curl invocation must be a single unbroken line. For complex JSON payloads, use `@file` references instead of inline data.

---

## Quick Reference: Flags You'll Use Constantly

```
-s            Silent mode, no progress bar (ALWAYS use in scripts)
-S            Show errors even in silent mode (pair with -s as -sS)
-f            Fail silently on HTTP errors (returns exit code 22)
-L            Follow redirects (ALWAYS include for URLs you don't control)
-o FILE       Write output to FILE
-O            Save with remote filename
-w FORMAT     Write out metadata after transfer (status codes, timing)
-X METHOD     Set HTTP method (POST, PUT, PATCH, DELETE)
-H "K: V"     Add header
-d 'data'     Send POST data (application/x-www-form-urlencoded)
-d @file      Send POST data from file
--json '{}'   Shorthand: sets Content-Type + Accept to JSON and sends data (curl 7.82+)
-u user:pass  Basic auth
-m SECONDS    Max time for entire operation
--retry N     Retry N times on transient failure
-k            Skip TLS verification (dev only, never production)
-i            Include response headers in output
-I            HEAD request, headers only
-v            Verbose (debug mode)
```

---

## Pattern: Simple GET

```bash
curl -sS https://api.example.com/endpoint
```

```bash
curl -sSf https://api.example.com/endpoint
```

The `-f` variant exits with code 22 on HTTP 4xx/5xx so your script can detect failure.

## Pattern: GET with Headers

```bash
curl -sS -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" https://api.example.com/data
```

Multiple `-H` flags on one line. Never split across lines.

## Pattern: GET and Save to File

```bash
curl -sSL -o output.json https://api.example.com/data
```

```bash
curl -sSL -O https://example.com/file.tar.gz
```

`-O` uses remote filename. `-o` lets you name it.

## Pattern: Check HTTP Status Code Only

```bash
curl -s -o /dev/null -w '%{http_code}' https://example.com
```

Returns just the status code (200, 404, etc). Perfect for health checks and conditional logic.

## Pattern: Headers Only (HEAD Request)

```bash
curl -sI https://example.com
```

## Pattern: POST JSON (Inline, Short Payloads)

```bash
curl -sS -X POST -H "Content-Type: application/json" -d '{"key":"value","name":"test"}' https://api.example.com/endpoint
```

For curl 7.82+, use `--json` shorthand:

```bash
curl -sS --json '{"key":"value","name":"test"}' https://api.example.com/endpoint
```

`--json` automatically sets Content-Type and Accept headers to application/json.

## Pattern: POST JSON (From File — USE THIS FOR COMPLEX PAYLOADS)

This is the most important pattern for agents. When the JSON is more than ~80 chars, write it to a file first, then reference it:

```bash
echo '{"name":"test","config":{"nested":"value","array":[1,2,3]},"verbose":true}' > /tmp/payload.json && curl -sS -X POST -H "Content-Type: application/json" -d @/tmp/payload.json https://api.example.com/endpoint
```

Or for truly complex payloads, create the file in a prior step:

```bash
# Step 1: create the payload file (use your file-writing tool)
# Step 2: send it
curl -sS -X POST -H "Content-Type: application/json" -d @payload.json https://api.example.com/endpoint
```

**The `@file` pattern is your best friend.** It keeps curl on one line regardless of payload complexity.

## Pattern: POST Form Data

```bash
curl -sS -X POST -d 'username=admin&password=secret' https://example.com/login
```

## Pattern: PUT / PATCH / DELETE

```bash
curl -sS -X PUT -H "Content-Type: application/json" -d '{"status":"active"}' https://api.example.com/resource/123
```

```bash
curl -sS -X PATCH -H "Content-Type: application/json" -d '{"status":"active"}' https://api.example.com/resource/123
```

```bash
curl -sS -X DELETE -H "Authorization: Bearer $TOKEN" https://api.example.com/resource/123
```

## Pattern: File Upload (Multipart)

```bash
curl -sS -F "file=@/path/to/file.pdf" -F "description=My upload" https://api.example.com/upload
```

Multiple `-F` flags for multiple fields/files, all on one line.

## Pattern: Download with Progress (User-Facing)

```bash
curl -L -o filename.zip https://example.com/filename.zip
```

Omit `-s` when you want the user to see download progress.

## Pattern: Download Script and Execute

```bash
curl -fsSL https://example.com/install.sh | bash
```

`-f` fail on error, `-sS` silent with errors, `-L` follow redirects. Standard install script pattern.

---

## Authentication Patterns

### Bearer Token
```bash
curl -sS -H "Authorization: Bearer $TOKEN" https://api.example.com/data
```

### Basic Auth
```bash
curl -sS -u username:password https://api.example.com/data
```

### API Key in Header
```bash
curl -sS -H "X-API-Key: $API_KEY" https://api.example.com/data
```

### API Key in Query Param
```bash
curl -sS "https://api.example.com/data?api_key=$API_KEY"
```

---

## Response Handling & Parsing

### Extract JSON Field (pipe to jq)
```bash
curl -sS https://api.example.com/data | jq '.field'
```

```bash
curl -sS https://api.example.com/data | jq -r '.items[].name'
```

### Save Response and Check Status
```bash
HTTP_CODE=$(curl -sS -o /tmp/response.json -w '%{http_code}' https://api.example.com/data) && echo "Status: $HTTP_CODE" && cat /tmp/response.json
```

### Get Response Headers and Body
```bash
curl -sS -i https://api.example.com/data
```

### Timing Diagnostics (Single Line)
```bash
curl -sS -o /dev/null -w 'dns:%{time_namelookup} connect:%{time_connect} ttfb:%{time_starttransfer} total:%{time_total}\n' https://example.com
```

---

## Robust Patterns for Scripts

### With Timeout and Retry
```bash
curl -sS -m 30 --retry 3 --retry-delay 2 https://api.example.com/data
```

### Fail-Safe GET (Timeout + Fail on Error + Retry)
```bash
curl -sSf -m 15 --retry 3 --retry-delay 1 -L https://api.example.com/data
```

### Conditional on Status Code
```bash
test "$(curl -s -o /dev/null -w '%{http_code}' https://example.com)" = "200" && echo "UP" || echo "DOWN"
```

### Save to Variable
```bash
RESPONSE=$(curl -sS https://api.example.com/data) && echo "$RESPONSE" | jq '.result'
```

---

## Common API Patterns

### GitHub API
```bash
curl -sS -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" https://api.github.com/repos/owner/repo/issues
```

### Create GitHub Issue
```bash
curl -sS -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github.v3+json" -d '{"title":"Bug report","body":"Description here"}' https://api.github.com/repos/owner/repo/issues
```

### OpenAI / Anthropic API (Use @file for the body)
```bash
echo '{"model":"claude-sonnet-4-20250514","max_tokens":1024,"messages":[{"role":"user","content":"Hello"}]}' > /tmp/req.json && curl -sS -X POST -H "x-api-key: $ANTHROPIC_API_KEY" -H "anthropic-version: 2023-06-01" -H "Content-Type: application/json" -d @/tmp/req.json https://api.anthropic.com/v1/messages
```

### Webhook POST
```bash
curl -sS -X POST -H "Content-Type: application/json" -d '{"text":"Deployment complete"}' https://hooks.slack.com/services/T00/B00/xxx
```

---

## Anti-Patterns: What NOT to Do

### NEVER: Backslash Continuation
```
# BAD — triggers permission prompts, breaks pattern matching
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"key": "value"}' \
  https://api.example.com/endpoint
```

### NEVER: Heredoc for Payload
```
# BAD — unparseable by permission systems, pollutes settings files
curl -X POST -H "Content-Type: application/json" -d @- https://api.example.com <<EOF
{
  "key": "value"
}
EOF
```

### NEVER: -k in Production
```
# BAD — disables TLS verification. Only for local dev with self-signed certs.
curl -k https://production.example.com/api
```

### INSTEAD: Use @file for Complex Bodies
```bash
# GOOD — write payload to file, reference it
echo '{"key":"value","nested":{"complex":"data"}}' > /tmp/body.json && curl -sS -X POST -H "Content-Type: application/json" -d @/tmp/body.json https://api.example.com/endpoint
```

### INSTEAD: Chain with && Not Multiline
```bash
# GOOD — single line with && for sequential operations
curl -sS -o /tmp/data.json https://api.example.com/step1 && curl -sS -X POST -d @/tmp/data.json https://api.example.com/step2
```

---

## Debugging

### Verbose Output
```bash
curl -v https://example.com 2>&1 | head -30
```

### See Request Headers Being Sent
```bash
curl -sS -v -o /dev/null https://example.com 2>&1 | grep '>'
```

### Test If URL Is Reachable
```bash
curl -sS -o /dev/null -w '%{http_code}' -m 5 https://example.com
```

### Follow Redirect Chain
```bash
curl -sSL -o /dev/null -w '%{url_effective}' https://short.url/abc
```

---

## SSL/TLS

### Specify CA Bundle
```bash
curl -sS --cacert /path/to/ca-bundle.crt https://api.example.com
```

### Client Certificate
```bash
curl -sS --cert /path/to/client.pem --key /path/to/client-key.pem https://api.example.com
```

### Skip TLS (Dev Only)
```bash
curl -sSk https://localhost:8443/api/health
```

---

## Permission Configuration (for Agent Environments)

For Claude Code, add to `.claude/settings.json` or `~/.claude/settings.json`:
```json
{
  "permissions": {
    "allow": [
      "Bash(curl:*)"
    ]
  }
}
```

Note: wildcard permission `Bash(curl:*)` matches single-line curl commands only. Multiline commands, heredocs, and backslash continuations will still trigger prompts even with this rule. This is the primary reason every pattern in this file is single-line.

For Cursor, add `curl` to your allowed terminal commands in settings.

---

## Quick Decision Tree

1. **Simple GET?** → `curl -sS URL`
2. **Need to follow redirects?** → Add `-L`
3. **Saving output?** → Add `-o file`
4. **POST with short JSON?** → `curl -sS --json '{"k":"v"}' URL`
5. **POST with complex JSON?** → Write to file first, use `-d @file`
6. **Need auth?** → `-H "Authorization: Bearer $TOKEN"`
7. **In a script?** → Always use `-sS`, add `-f` for fail detection, add `-m` for timeout
8. **Debugging?** → Add `-v`, pipe stderr: `2>&1`
9. **Health check?** → `curl -s -o /dev/null -w '%{http_code}' URL`
10. **Download file?** → `curl -sSL -o filename URL`
