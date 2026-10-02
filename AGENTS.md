# Frictionless

- No ternary operators.
- Keep architecture small and native. Avoid third-party dependencies.
- Store mutations go through RecordingStore transactions. Do not store interval history in preferences.
- Preserve history, the one-open-interval invariant, and timestamp continuity.
- Recording remains authoritative when Live Activity presentation fails.
- Do not put fake records in normal first-launch storage.
- After first-run onboarding, keep the task picker as the app's initial screen; a routine switch takes one tap.
- Use meaningful storage/calendar and user-flow tests. Do not claim device or signing checks without evidence.
