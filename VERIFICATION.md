# Verification — September 30, 2026

Built with Xcode 26.0.1 / iOS 26 SDK. App and embedded Live Activity extension build and sign locally for the simulator. Minimum deployment target remains iOS 17.

## Passed

On iPhone 15 Pro / iOS 17.0:

- **10 unit tests:** first start, switch, shared timestamp, same-task no-op, stop, 30 concurrent independent-store requests, persistence/relaunch, interrupted SQLite transaction recovery, normal App Group access, Undo expiry/invalidation, safe corrections/shared boundaries, archive, midnight clipping, active totals, and 23/25-hour daylight-saving days.
- **3 UI tests:** fresh empty state, task creation, one-tap switching, selected state, relaunch persistence, audit/editor navigation, Stop/Undo, largest accessibility text size, and saving a five-minute switch correction. The correction changes Writing to 55 minutes and Reading to 1 hour 5 minutes while retaining the 2-hour total.
- A subsequent targeted audit UI test passed after making its isolated fixture independent of the current time of day and guarding simultaneous launch refreshes from installing it twice.

The complete suite reported `TEST SUCCEEDED`; the final fixture test also reported `TEST SUCCEEDED`. Earlier failing runs were resolved before delivery. Simulator signing used a local ad-hoc identity, not an Apple Developer identity.

Inspected rendered empty/task screens, audit bars/timeline, interval editor, and largest-text picker/audit. Also inspected iOS 26 simulator renders during implementation. Saved iOS 17 screenshots: [Tasks](Screenshots/tasks.png), [Audit after correction](Screenshots/audit.png), [Largest-text audit](Screenshots/large-text-audit.png). Screenshot records exist only in explicit debug UI-test storage; normal first launch is empty.

## Task picker update

The three UI tests passed again after replacing the add-task sheet with inline creation in the manager and moving Today / Manage tasks to the bottom. Inspected empty and populated picker screenshots: the background fills the screen. Bottom controls stack vertically at accessibility text sizes; a targeted largest-text test verifies that layout. Storage logic is unchanged; the ten unit tests above were not rerun for this UI-only update.

## Remaining device checks

No physical iPhone was available for testing. Select your actual developer team and enable the shared App Group on both targets before running on your iPhone. Device provisioning/signing has not been verified.

The Live Activity extension and LiveActivityIntent actions are implemented and compile. Physical Lock Screen/compact/minimal/expanded Dynamic Island presentation, direct shortcut execution while locked/after app termination, disabled/dismissed activities, and eight-hour expiration still need device verification. Do not interpret simulator UI tests as proof of those physical-device behaviors. VoiceOver labels and Dynamic Type are implemented; a spoken VoiceOver pass on hardware remains unchecked.

Apple supports foreground Live Activity requests and the LiveActivityIntent background exception. Presentation has an eight-hour active lifetime; recording continues from saved timestamps. There is no renewal service. References: [Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities), [LiveActivityIntent](https://developer.apple.com/documentation/appintents/liveactivityintent).

## Simulator environment

App Group access requires simulator entitlements, so do not build tests with `CODE_SIGNING_ALLOWED=NO`. Use local ad-hoc signing as shown in the README. A synced Documents directory added Finder metadata to build products and prevented code signing; building in `/tmp` resolved it. One test-host launch stalled without loading XCTest; restarting the task's simulator resolved that launch issue.
