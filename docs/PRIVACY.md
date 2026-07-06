# Privacy

Trace is designed to keep user data local unless the user explicitly uses the Coach.

## Stored Locally

- Plans
- Goals
- Activity samples
- Coach summaries
- Coach identity, active conversations, and archived conversations
- Optional snapshot paths
- Optional OCR text snippets

## API Key Storage

API keys are stored locally and are not written to the repository:

- macOS: Keychain through `KeychainStore.swift`.
- Windows: Electron `safeStorage` encryption, with encrypted values stored inside the Windows app data directory.

## Screen Capture and OCR

Screen snapshots are disabled by default. When enabled:

- Snapshots are saved locally.
- OCR is performed locally before summary context is prepared.
- macOS uses Apple's Vision framework.
- Windows uses local Windows OCR APIs on captured screenshots when available.
- OCR text may be included in Coach context.

## Sent to AI Provider

When the user generates a summary, the configured API provider may receive:

- Task titles and notes
- Goal titles and metrics
- App usage distribution
- Window timeline blocks
- Selected OCR text snippets
- Coach identity, current conversation context, durable memory, and recent archived summaries when needed for planning continuity

Do not enable screenshots/OCR if your screen may contain sensitive material that should not be summarized.

Deleting a conversation does not delete durable Coach memory. Changing identity archives the current identity's conversations and memory, then starts a new identity profile.
