# Frictionless

A local, native iPhone time record. Open to a stable task list. Tap a task once to switch. Audit your day later. SwiftUI, iOS 17+, no dependencies, accounts, network services, or sample history.

## Run on your iPhone

1. Open `Frictionless.xcodeproj` in Xcode. Select the **Frictionless** scheme.
2. Select your Apple Developer team in Signing & Capabilities for **Frictionless** and **FrictionlessLiveActivity**. Do not change the test targets' host settings.
3. If the bundle identifiers are unavailable, change `APP_BUNDLE_ID` in `Configuration/Signing.xcconfig` to a unique identifier. The extension identifier and App Group follow it. Register/enable the same App Group for both targets. Keep `RecordingAppGroup` and the entitlements matched. Changing the group later starts a separate database; keep the old group if you need its history.
4. Connect/unlock your iPhone, enable Developer Mode if prompted, select it as the destination, and Run. Allow Live Activities in iOS Settings for Frictionless.

Alternatively, keep personal settings out of Git with `Configuration/Local.xcconfig`:

```xcconfig
DEVELOPMENT_TEAM = YOUR_ACTUAL_TEAM_ID
APP_BUNDLE_ID = com.yourname.frictionless
```

No Apple team identifier is supplied or assumed. A simulator build does not prove device signing. You must select your own team.

## Use

- Add a task with just its name. The first three tasks become Live Activity shortcuts.
- Tap a row to start or switch immediately. Tapping the current task does nothing. Stop tracking is explicit; Undo appears for eight seconds after recording changes.
- Manage tasks to rename, reorder, pick muted colors, choose up to three shortcuts, or archive. Archive keeps history and closes an active interval.
- Today opens day navigation, duration bars, and a chronological timeline with untracked gaps. Tap an interval to correct its task or times. “Started earlier” offers 5/15/30-minute offsets. Enable “Adjust previous task’s end too” to move a shared switch boundary atomically. Other overlaps, future timestamps, and negative durations are rejected.
- Live Activities offer direct shortcut buttons, Stop, and All tasks. Tapping the body opens Tasks. Standard system touch-and-hold expands the Dynamic Island.

## Storage and lifecycle

Both targets use the same SQLite file in an App Group. A compact Codable state containing tasks, intervals, revision, and Undo is stored as one row. Every mutation uses `BEGIN IMMEDIATE`, rereads the latest state, validates, and commits with WAL and `synchronous=FULL`. SQLite serializes independent stores/processes and recovers unfinished transactions. Read/decode/validation failures preserve the database and report errors instead of resetting history. This small personal database favors a simple transaction over additional ORM/schema machinery.

There is at most one open interval. Switching closes and starts at one timestamp. Zero-length records from rapid switches are valid and excluded from visible day totals. Undo restores the preceding recording state only while its revision/token remains current and its eight-second window is open. Any management/correction change invalidates Undo.

The saved timestamp continues through suspension, termination, clock changes, and expired presentations. Daily audit clips to local calendar boundaries (including 23/25-hour daylight-saving days) without changing history. The currently selected system timezone governs historical day display.

Live Activity presentation is separate from recording. Each new interval ends existing activities and requests a fresh one with the recorded start timestamp. Reconciliation on launch/foreground refreshes an existing matching activity or restores a missing presentation. A serialized presentation queue prevents duplicate requests across overlapping app actions. LiveActivityIntent runs recording through the same store and reconciles afterward; failed presentation never rolls back recording. Disabled/dismissed/unavailable presentations are tolerated.

**Eight-hour limitation:** iOS caps the active lifetime of a Live Activity at eight hours. Recording continues without splitting the interval. The next eligible app/intent interaction restores presentation. There is no automatic renewal, background timer, push service, or backend. Apple documents the foreground request rule and the LiveActivityIntent background exception: [Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), [LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent).

## Build and tests

```sh
xcodebuild -project Frictionless.xcodeproj -scheme Frictionless \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO test
```

Choose an installed simulator in Xcode or `xcrun simctl list devices available`. The project contains app, embedded WidgetKit Live Activity extension, unit tests, and UI tests. No project generator is required.

Unit tests cover transitions/no-op, independent concurrent stores, relaunch, uncommitted-write recovery, Undo expiration/invalidation, correction overlap and shared boundaries, archive, midnight, active totals, and daylight-saving day lengths. UI tests use an explicit debug-only isolated test database (never normal first-launch history), attach screenshots, and exercise empty state, creation, switching, relaunch, audit/correction navigation, Stop/Undo, and accessibility text sizes.

See [VERIFICATION.md](VERIFICATION.md) for actual results and remaining hardware checks.
