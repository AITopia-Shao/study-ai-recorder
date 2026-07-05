# Architecture

StudyAI Recorder is a local-first SwiftUI macOS app built as a Swift Package executable target.

## Layers

- UI: `Views.swift`
- State orchestration: `AppState.swift`
- Persistence: `Storage.swift`
- Domain models: `Models.swift`
- Activity collection: `ActivityMonitor.swift`
- AI provider client: `AIClient.swift`
- Learning agent pipeline: `LearningAgent.swift`
- Secrets: `KeychainStore.swift`

## Data Flow

1. The user creates plans and goals in SwiftUI views.
2. `AppState` persists changes to the local JSON database.
3. `ActivityMonitor` samples the foreground app and active window title.
4. Optional snapshots are captured with `screencapture`.
5. Optional OCR runs locally through Apple's Vision framework.
6. `LearningDayContext` compacts tasks, goals, samples, app usage, timeline blocks, and OCR snippets.
7. `LearningScoreRubric` computes a deterministic score.
8. `AIClient` sends a locked-score prompt to an OpenAI-compatible API.
9. The model returns JSON matching `StudyAgentReport`.
10. `LearningSummaryRenderer` renders a stable human-readable report.

## Agent Design

The AI system is intentionally split into skills:

- Evidence audit
- Stable scoring
- Trajectory synthesis
- Goal alignment
- Focus recovery
- Tomorrow planning

The model does not choose the score. It explains and summarizes evidence after the app has calculated the score locally.

## Storage

The app stores user data under:

```text
~/Library/Application Support/StudyAIRecorder/
```

API keys are stored in Keychain, not in the JSON database.
