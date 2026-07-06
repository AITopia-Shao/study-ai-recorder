# Architecture

Trace is a local-first desktop app. The macOS implementation is a SwiftUI app built as a Swift Package executable target, and the Windows implementation is an Electron parity build that preserves the same planning, coaching, memory, archive, and monitoring semantics.

## Layers

- UI: `Views.swift`
- State orchestration: `AppState.swift`
- Persistence: `Storage.swift`
- Domain models: `Models.swift`
- Activity collection: `ActivityMonitor.swift`
- AI provider client: `AIClient.swift`
- Review pipeline: `LearningAgent.swift`
- Coach runtime: `PlanningCoachAgent.swift`
- Secrets: `KeychainStore.swift`
- Windows parity: `windows/main.js`, `windows/preload.js`, `windows/src/`

## Data Flow

1. The user creates plans and goals in the unified Planning workspace.
2. `AppState` persists changes to the local JSON database.
3. Today displays due plans and active goals, and records completion notes, plan diaries, milestone changes, and goal stage logs.
4. `ActivityMonitor` samples the foreground app and active window title.
5. Optional snapshots are captured locally.
6. Optional OCR runs locally through platform OCR APIs.
7. `PlanningCoachAgent` compacts identity, plans, goals, logs, summaries, samples, app usage, timeline blocks, OCR snippets, recent conversation, archived memory, and coach memory.
8. `AIClient` sends a strict JSON coach prompt to an OpenAI-compatible API.
9. The model can return a user reply, planning tool actions, memory updates, scoped file actions, and an optional daily review.
10. `AppState` executes allowed actions against the local database and `CoachFiles/` directory.
11. For daily reviews, `LearningScoreRubric` computes a deterministic score and `LearningSummaryRenderer` renders a stable report.

## Coach Design

The Coach is inspired by the `claw-code` agent boundary, adapted to a local planning app:

- Conversation messages are stored as `CoachMessage`.
- Conversation threads are stored as `CoachConversation`, with delete/rename support.
- Identity changes and daily rollover create `CoachConversationArchive` records grouped by identity.
- Durable memory is stored as `CoachMemory`.
- Tool actions are typed as `CoachAction`.
- The tool surface is limited to plans, goals, diaries, stage logs, summaries, activity context, and the local coach file directory.
- The model must return strict JSON; `AppState` performs the actual mutation.
- Daily review remains deterministic-scoring-first: the model can explain and summarize, but the app owns the score.

The model does not choose the score. It explains and summarizes evidence after the app has calculated the score locally.

## Storage

The app stores user data under the legacy directory name for compatibility:

```text
~/Library/Application Support/StudyAIRecorder/
```

API keys are not stored as plaintext in the JSON database. macOS uses Keychain; Windows stores Electron safeStorage-encrypted values in the app data database.

Public product naming is `Trace`, but local storage intentionally keeps the legacy directory names so existing installs keep their database and encrypted API key state.

Coach files and archived conversations are scoped to the same legacy data directories:

```text
~/Library/Application Support/StudyAIRecorder/CoachFiles/
%APPDATA%/StudyAI Recorder/CoachFiles/
~/Library/Application Support/StudyAIRecorder/CoachArchives/
%APPDATA%/StudyAI Recorder/CoachArchives/
```
