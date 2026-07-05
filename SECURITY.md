# Security Policy

## Supported Versions

The `main` branch is the active development line.

## Reporting a Vulnerability

Please use GitHub private vulnerability reporting if it is enabled for this repository. If it is not enabled, open a minimal issue that does not disclose exploit details and ask for a private contact path.

## Sensitive Data

Do not commit:

- API keys or provider tokens
- Local databases from Application Support
- Screen snapshots
- OCR text dumps
- Build artifacts

API keys are stored in macOS Keychain. Optional screenshots and OCR output are local user data and should not be included in issues or pull requests unless explicitly redacted.
