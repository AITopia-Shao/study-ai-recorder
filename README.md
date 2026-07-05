# StudyAI Recorder

StudyAI Recorder is a cross-platform learning planner and activity journal. It combines lightweight planning, goal tracking, foreground app/window monitoring, optional local screen OCR, and a structured AI learning-management agent that turns each day into a concise review.

The app is designed for learners and builders who want a private, local-first record of what they planned, what they actually did, and what to improve tomorrow.

## Highlights

- Native SwiftUI macOS app
- Windows parity build packaged as an Electron desktop app
- Plan mode for daily tasks
- Goal mode for longer learning outcomes
- Foreground app and window-title sampling
- Optional screen snapshots with on-device OCR
- Local secure API key handling: macOS Keychain and Windows safeStorage encryption
- OpenAI-compatible chat completions endpoint support
- Stable AI review pipeline with deterministic local scoring
- Day theme inspired by a tree-lined boulevard
- Night theme inspired by a quiet starlit workspace

## AI Agent System

StudyAI Recorder does not ask the model to improvise a free-form diary. It runs a small learning-management agent pipeline:

1. Build an evidence context from tasks, goals, app usage, window timeline, and OCR snippets.
2. Compute a local 1-10 score with a deterministic rubric.
3. Lock the score before sending context to the model.
4. Enable learning skills such as evidence audit, goal alignment, focus recovery, and tomorrow planning.
5. Require strict JSON from the model.
6. Render the report in a stable format inside the app.

This keeps scores more consistent and prevents long, drifting, or overly chatty summaries.

## Screens

- Today: daily overview, quick capture, active mode, metrics, app usage, and timeline
- Plan: daily executable tasks
- Goals: longer outcomes with milestones and progress
- Monitor: current foreground app/window and recent timeline
- AI Summary: structured daily review
- Settings: API, theme, sampling, OCR, and agent skill settings

## Requirements

- macOS 14 or later for the native SwiftUI app
- Windows 10 or later for the Electron parity app
- Apple Command Line Tools or Xcode for macOS builds
- Swift Package Manager for macOS builds
- Node.js/npm for Windows builds
- An OpenAI-compatible chat completions API if you want AI summaries

## Run Locally

```bash
CLANG_MODULE_CACHE_PATH="$PWD/.build/clang-module-cache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/swiftpm-module-cache" \
swift run --disable-sandbox --cache-path "$PWD/.build/swiftpm-cache"
```

On a normal developer machine outside Codex sandboxing, `swift run` is usually enough.

## Build a macOS App

```bash
chmod +x scripts/build_app.sh
scripts/build_app.sh
open "dist/StudyAI Recorder.app"
```

The generated app bundle is ignored by git and lives under `dist/`.

## Package a Release

```bash
chmod +x scripts/package_release.sh
scripts/package_release.sh 0.1.0
```

This creates a macOS package:

- `dist/release/StudyAI-Recorder-v0.1.0-macOS-arm64.zip`
- `dist/release/StudyAI-Recorder-v0.1.0-macOS-arm64.zip.sha256`

Current public downloads are published from GitHub Releases. Tagged releases also build a Windows installer:

- `StudyAI-Recorder-v0.1.0-Windows-x64-Setup.exe`
- `StudyAI-Recorder-v0.1.0-Windows-x64-Setup.exe.sha256`

The Windows app is an Electron parity build with the same product surface as the macOS app: plan mode, goal mode, foreground process/window monitoring, optional screenshots with best-effort local OCR, themes, stable scoring, and OpenAI-compatible AI summaries.

## AI Setup

Open Settings in the app and configure:

- API URL, for example `https://api.openai.com/v1`
- Model, for example `gpt-4o-mini`
- API Key

API keys are saved locally and are not written to the repository.

## Privacy

StudyAI Recorder is local-first:

- Tasks, goals, activity samples, and summaries are stored locally.
- API keys are stored locally: macOS Keychain on macOS; Electron safeStorage-encrypted values in Windows app data on Windows.
- Screen snapshots and OCR are disabled by default.
- OCR is performed locally before any text is sent to the AI endpoint: Apple's Vision framework on macOS, Windows OCR APIs on Windows.
- When AI summary generation is used, selected task, goal, timeline, app usage, and OCR text context is sent to the configured API provider.

See [docs/PRIVACY.md](docs/PRIVACY.md) for details.

## Data Locations

Local database:

```text
~/Library/Application Support/StudyAIRecorder/database.json
%APPDATA%/StudyAI Recorder/database.json
```

Optional snapshots:

```text
~/Library/Application Support/StudyAIRecorder/Snapshots/
%APPDATA%/StudyAI Recorder/Snapshots/
```

## Project Structure

```text
Sources/StudyAIRecorder/
  ActivityMonitor.swift   foreground app, window timeline, screenshots, OCR
  AIClient.swift          OpenAI-compatible chat completions client
  AppEntry.swift          SwiftUI app entry point
  AppState.swift          app state and persistence coordination
  KeychainStore.swift     API key storage
  LearningAgent.swift     agent context, skills, rubric, report rendering
  Models.swift            Codable domain models and settings
  Storage.swift           local JSON database
  Views.swift             SwiftUI screens and theme system
windows/
  main.js                 Electron main process, storage, monitoring, screenshots, OCR, AI summaries
  preload.js              Safe renderer bridge
  src/                    Windows parity UI
```

## Roadmap

- Menu bar recorder mode
- Weekly and monthly trend summaries
- Calendar export
- Better activity categorization rules
- Optional local-only model adapters
- Release notarization

## Contributing

Contributions are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) before opening a pull request.

## License

MIT. See [LICENSE](LICENSE).
