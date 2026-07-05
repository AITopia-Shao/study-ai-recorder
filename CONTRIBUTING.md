# Contributing

Thanks for improving StudyAI Recorder.

## Local Development

```bash
swift build
swift run
```

If you are running inside a restricted sandbox, use the cache flags documented in `README.md`.

## Pull Request Checklist

- Keep user data local-first by default.
- Do not commit API keys, screenshots, databases, or build artifacts.
- Run `swift build` before opening a PR.
- Update docs when behavior changes.
- Keep AI output deterministic where possible: score locally, ask the model for structured evidence and advice.

## UI Principles

- Prefer native macOS controls and predictable layouts.
- Keep dense work surfaces calm and scannable.
- Do not add decorative elements that reduce readability.
- Respect light and dark themes.

## AI Principles

- Never ask the model to invent missing activity.
- Separate evidence collection, scoring, model generation, and rendering.
- Keep summaries short, stable, and actionable.
- Treat screen OCR text as sensitive data.
