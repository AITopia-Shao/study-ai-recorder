# Trace

Trace is a local-first planning coach and activity journal for macOS and Windows. It combines short-term plans, long-term goals, foreground app/window monitoring, optional local screen OCR, and a coach agent that can summarize records, update planning data, keep memory, and write scoped coach files.

The app is designed for learners and builders who want a private, local-first record of what they planned, what they actually did, and what to improve tomorrow.

## Highlights

- Native SwiftUI macOS app and Electron Windows parity app
- Unified Planning workspace for daily plans and long-term goals
- Today workspace for plan completion, daily diary, goal milestones, and stage logs
- Foreground app and window-title sampling
- Optional screen snapshots with on-device OCR
- Local secure API key handling: macOS Keychain and Windows safeStorage encryption
- OpenAI-compatible chat completions endpoint support
- Coach agent with conversations, rename/delete, identity-aware memory, archive history, structured planning actions, and scoped file operations
- Stable review pipeline with deterministic local scoring
- Day, night, and custom 18-bit global theme colors
- Markdown and LaTeX rendering in coach messages

## Coach Agent

Trace does not treat AI as a standalone summary button. The Coach uses a local agent boundary inspired by `claw-code`: conversation state, structured tool actions, scoped file operations, permission boundaries, memory updates, and context compaction.

The coach can:

- Read plans, goals, logs, summaries, activity samples, app usage, window timeline, and OCR snippets.
- Add, update, delete, and complete plans through structured actions.
- Add, update, delete, and progress long-term goals.
- Append plan diaries and goal stage logs.
- Keep durable coach memory in the local database.
- Use identity information such as "first-year computer science student" as long-term coaching background.
- Archive conversations by identity when identity changes and during daily rollover.
- Read and write files inside the local `CoachFiles/` area.
- Produce stable daily reviews with the same deterministic local scoring rubric.

## Screens

- Today: today's plans and goals, completion marking, plan diary, and goal stage logs
- Planning: plan creation with start and completion dates, automatic completion-date grouping, goal creation, metrics, and read-only stage-log browsing
- Monitor: recording duration, current foreground app/window, app usage, and window timeline
- Coach: interactive conversation, planning actions, memory, Markdown/LaTeX rendering, and daily review
- Settings: identity, archived conversations, API, global theme, sampling, OCR, and agent skill settings

## Requirements

- macOS 14 or later for the native SwiftUI app
- Windows 10 or later for the Electron parity app
- Apple Command Line Tools or Xcode for macOS builds
- Swift Package Manager for macOS builds
- Node.js/npm for Windows builds
- An OpenAI-compatible chat completions API if you want coach responses and summaries

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
open "dist/Trace.app"
```

The generated app bundle is ignored by git and lives under `dist/`.

## Package a Release

```bash
chmod +x scripts/package_release.sh
scripts/package_release.sh 0.1.0
```

This creates a macOS package:

- `dist/release/Trace-v0.1.0-macOS-arm64.zip`
- `dist/release/Trace-v0.1.0-macOS-arm64.zip.sha256`

Current public downloads are published from GitHub Releases. Tagged releases also build a Windows installer:

- `Trace-v0.1.0-Windows-x64-Setup.exe`
- `Trace-v0.1.0-Windows-x64-Setup.exe.sha256`

To package the Windows app locally from this repository:

```bash
chmod +x scripts/package_windows.sh
scripts/package_windows.sh 0.1.0
```

This creates:

- `dist/release/Trace-v0.1.0-Windows-x64-Setup.exe`
- `dist/release/Trace-v0.1.0-Windows-x64-Setup.exe.sha256`

The Windows app is maintained as a strict Electron parity build for the macOS product surface.

## AI Setup

Open Settings in the app and configure:

- API URL, for example `https://api.openai.com/v1`
- Model, for example `gpt-4o-mini`
- API Key

Recording start/pause lives at the bottom of the sidebar. The Coach is always available; without an API key it falls back to local guidance.

API keys are saved locally and are not written to the repository.

## Privacy

Trace is local-first:

- Tasks, goals, activity samples, and summaries are stored locally.
- API keys are stored locally: macOS Keychain on macOS; Electron safeStorage-encrypted values in Windows app data on Windows.
- Screen snapshots and OCR are disabled by default.
- OCR is performed locally before any text is sent to the AI endpoint: Apple's Vision framework on macOS, Windows OCR APIs on Windows.
- When the Coach is used, selected plans, goals, logs, summaries, timeline, app usage, and OCR text context is sent to the configured API provider.

See [docs/PRIVACY.md](docs/PRIVACY.md) for details.

## Data Locations

Local database. Existing installs keep the legacy directory name so data and API keys are not lost, even though the public product name is `Trace`:

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
  LearningAgent.swift     review context, skills, rubric, report rendering
  Models.swift            Codable domain models and settings
  PlanningCoachAgent.swift conversation protocol, planning tools, memory, scoped file actions
  Storage.swift           local JSON database
  Views.swift             SwiftUI screens and theme system
windows/
  main.js                 Electron main process, storage, monitoring, screenshots, OCR, planning coach
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
