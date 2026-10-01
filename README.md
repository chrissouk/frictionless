# Frictionless

A minimal native iPhone time record. Tap a task to switch. Audit your day later. iOS 17+, SwiftUI, local storage, no third-party dependencies or backend.

## Run on your iPhone

1. Open `Frictionless.xcodeproj` and select the **Frictionless** scheme.
2. Select your Apple Developer team for **Frictionless** and **FrictionlessLiveActivity** in Signing & Capabilities.
3. If necessary, change `APP_BUNDLE_ID` in `Configuration/Signing.xcconfig` to a unique identifier. Enable the same App Group on both targets; its name follows the bundle identifier. Keep the entitlements and `RecordingAppGroup` matched.
4. Connect/unlock your iPhone, enable Developer Mode if prompted, select it as the destination, and Run.

No Apple team identifier is supplied. For personal settings excluded from Git, create `Configuration/Local.xcconfig`:

```xcconfig
DEVELOPMENT_TEAM = YOUR_ACTUAL_TEAM_ID
APP_BUNDLE_ID = com.yourname.frictionless
```

Changing the App Group creates a separate database; retain the old group to retain its history.

## Use

- Add task opens the manager. Enter names inline with New task, then tap a task in the picker to record. The active task moves into a colored Now section with elapsed time; other tasks keep their saved order. Same-task taps do nothing. Stop tracking sits above the bottom navigation. Undo lasts eight seconds and expires after later changes.
- Manage tasks to rename, reorder, choose a muted color, or archive. Archive retains history and stops an active task.
- Today and Manage tasks sit at the bottom of the picker. Today opens duration bars and a timeline with untracked gaps. Tap an interval to correct its task or times. Moving a shared switch boundary also adjusts the previous task’s end. Invalid overlaps, negative durations, and future edits are rejected.
- Recording appears automatically on the Lock Screen and Dynamic Island with the task color and elapsed time. Switch! opens the task picker. Standard system touch-and-hold expands the Dynamic Island.

Records use transactional SQLite in an App Group, shared by the app and intents. Saved recording remains authoritative if presentation fails. Day totals use local calendar boundaries, including daylight-saving changes.

## Simulator verification

```sh
xcodebuild -project Frictionless.xcodeproj -scheme Frictionless \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -derivedDataPath /tmp/FrictionlessDerivedData CODE_SIGN_IDENTITY=- test
```

Choose an installed simulator. Local ad-hoc signing enables App Group entitlements without an Apple team. Do not disable simulator code signing. Keeping build products outside a synced Documents directory avoids Finder metadata signing errors.

[Actual verification results and remaining device checks](VERIFICATION.md)
