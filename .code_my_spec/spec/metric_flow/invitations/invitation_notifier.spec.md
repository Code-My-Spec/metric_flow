# MetricFlow.Invitations.InvitationNotifier

Email delivery module using Swoosh. Sends transactional invitation emails via MetricFlow.Mailer. Delivers account invitation emails to prospective members, including the acceptance URL they must visit to join an account. The raw invitation token is embedded in the acceptance URL and is never stored directly — only its hash is persisted in the database. Invitations expire after 7 days.

## Delegates

None

## Functions

### deliver_invitation/3

Sends an invitation email to the given recipient email address containing the account name and a pre-built acceptance URL.

```elixir
@spec deliver_invitation(String.t(), String.t(), String.t()) :: {:ok, Swoosh.Email.t()} | {:error, term()}
```

**Process**:
1. Compose a plain-text email body containing a greeting addressed to the recipient email, the inviting account name, and the acceptance URL
2. Include a notice that the invitation expires in 7 days and a note that the email can be ignored if unexpected
3. Call the private deliver/3 helper with the recipient email, a subject line of "You've been invited to {account_name}", and the composed body
4. Build a Swoosh.Email struct with to set to the recipient, from set to "MetricFlow" / contact@example.com, the subject, and the plain-text body
5. Deliver the email via MetricFlow.Mailer.deliver/1
6. Return {:ok, email} on success or propagate {:error, reason} from the mailer

**Test Assertions**:
- sends an email to the recipient address
- sets the subject to include the account name
- includes the acceptance URL in the email body
- includes the 7-day expiry notice in the email body
- returns {:ok, email} when delivery succeeds
- returns {:error, reason} when the mailer fails

## Dependencies

- Swoosh.Email
- MetricFlow.Mailer
