# Contributing

Thanks for taking a look at Claude Guard.

## Development

Run the local check harness before opening a pull request:

```bash
./scripts/check.sh
```

The project intentionally keeps runtime dependencies small:

- bash
- curl
- jq

## Scope

Good contributions:

- make startup checks more reliable
- improve dry-run diagnostics
- reduce false positives
- improve documentation and examples
- add tests for guard behavior

Out of scope:

- TLS MITM
- request body rewriting
- base URL rewriting
- token extraction or credential forwarding
- anti-detection or fingerprint spoofing features

## Secrets

Do not commit:

- OAuth tokens
- API keys
- real Claude settings files
- live diagnostic logs
- personal proxy credentials
- private IP allowlists that identify a user environment

Use documentation-only example addresses such as `203.0.113.10`.
