# Privacy

StudyAI Recorder is designed to keep user data local unless the user explicitly requests an AI summary.

## Stored Locally

- Plans
- Goals
- Activity samples
- AI summaries
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
- OCR text may be included in AI summary context.

## Sent to AI Provider

When the user generates a summary, the configured API provider may receive:

- Task titles and notes
- Goal titles and metrics
- App usage distribution
- Window timeline blocks
- Selected OCR text snippets

Do not enable screenshots/OCR if your screen may contain sensitive material that should not be summarized.
