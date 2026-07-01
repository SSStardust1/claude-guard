# Security Policy

## Supported Versions

Only the latest tagged release is actively maintained.

## Reporting a Vulnerability

Please open a private vulnerability report through GitHub Security Advisories
for this repository.

Do not file public issues containing:

- access tokens
- OAuth credentials
- API keys
- proxy credentials
- raw `~/.claude` or `~/.claude-official` contents
- diagnostic logs that include private infrastructure details

## Project Boundaries

Claude Guard is a local startup guard and dry-run observer for official Claude
Code usage. It is not designed to bypass service policies or hide abusive
automation.

This project does not implement or accept:

- TLS interception
- request modification
- credential forwarding
- OAuth token reuse in third-party clients
- anti-detection fingerprint spoofing
