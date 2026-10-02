# Verification — September 30, 2026

Built with Xcode 26.0.1 / iOS 26 SDK. App and embedded Live Activity extension build and sign locally for the simulator. Minimum deployment target remains iOS 17.

## Passed

On iPhone 15 Pro / iOS 17.0:

- **10 unit tests:** first start, switch, shared timestamp, same-task no-op, stop, 30 concurrent independent-store requests, persistence/relaunch, interrupted SQLite transaction recovery, normal App Group access, Undo expiry/invalidation, safe corrections/shared boundaries, archive, midnight clipping, active totals, and 23/25-hour daylight-saving days.
- **3 UI tests:** fresh empty state, task creation, one-tap switching, selected state, relaunch persistence, audit/editor navigation, Stop/Undo, largest accessibility text size, and saving a five-minute switch correction. The correction changes Writing to 55 minutes and Reading to 1 hour 5 minutes while retaining the 2-hour total.
- A subsequent targeted audit UI test passed after making its isolated fixture independent of the current time of day and guarding simultaneous launch refreshes from installing it twice.

The complete suite reported `TEST SUCCEEDED`; the final fixture test also reported `TEST SUCCEEDED`. Earlier failing runs were resolved before delivery. Simulator signing used a local ad-hoc identity, not an Apple Developer identity.

Inspected rendered empty/task screens, audit bars/timeline, interval editor, and largest-text picker/audit. Saved screenshots: [Tasks on iOS 26](Screenshots/tasks.png), [Audit after correction on iOS 17](Screenshots/audit.png), [Largest-text audit on iOS 17](Screenshots/large-text-audit.png). Screenshot records exist only in explicit debug UI-test storage; normal first launch is empty.

## Task picker update

The three UI tests passed again after replacing the add-task sheet with inline creation in the manager and moving Today / Manage tasks to the bottom. Inspected empty and populated picker screenshots: the background fills the screen. Bottom controls stack vertically at accessibility text sizes; a targeted largest-text test verifies that layout. Storage logic is unchanged; the ten unit tests above were not rerun for this UI-only update.

## Active task and activity display

On iPhone 17 Pro / iOS 26, 13 unit tests and 4 UI tests passed. The activity displays task color and elapsed time with a single Switch! link to the picker; the activity switching/paging intents were removed. The active task appears once in a tinted Now section, with elapsed time replacing the checkmark. Stop tracking sits above bottom navigation. Unit coverage includes original start timestamps, color edits without restarting recording, persistence, bounded Unicode payloads, and compatibility with older saved data. UI coverage checks switching/relaunch, active-row position, bottom Stop placement, color selection/persistence, audit correction, and largest text. Screenshots confirm the visible “What’s next?” header and active-row layout.

## Onboarding — October 1, 2026

On iPhone 17 Pro / iOS 26, all 13 unit tests and 5 UI tests passed. First launch replaces the empty-task screen with a short introduction, inline task setup, current-task selection, and a background-recording/privacy reminder. Tests cover multiple tasks, disabled empty continuation, resuming setup across launches, returning to task setup, recording before the reminder is dismissed, completed-onboarding bypass, existing-user bypass, and largest text. Inspected the normal and largest-text screenshots. Startup refreshes are guarded against overlapping loads so existing tasks determine the first screen consistently.

Saved screenshots: [Introduction](Screenshots/onboarding-intro.png), [Task setup](Screenshots/onboarding-tasks.png), [Reminder](Screenshots/onboarding-reminder.png).

## Remaining device checks

No physical iPhone was available for testing. Select your actual developer team and enable the shared App Group on both targets before running on your iPhone. Device provisioning/signing has not been verified.

The Live Activity extension compiles. Physical Lock Screen/compact/minimal/expanded Dynamic Island presentation, Switch! opening the picker while locked/after app termination, disabled/dismissed activities, and eight-hour expiration still need device verification. Do not interpret simulator UI tests as proof of those physical-device behaviors. VoiceOver labels and Dynamic Type are implemented; a spoken VoiceOver pass on hardware remains unchecked.

Presentation has an eight-hour active lifetime; recording continues from saved timestamps. That baseline had no renewal service; see the issues 3/4/6 update below for the bounded iOS 26 successor. Reference: [Live Activities](https://developer.apple.com/documentation/activitykit/displaying-live-data-with-live-activities).

## Simulator environment

App Group access requires simulator entitlements, so do not build tests with `CODE_SIGNING_ALLOWED=NO`. Use local ad-hoc signing as shown in the README. A synced Documents directory added Finder metadata to build products and prevented code signing; building in `/tmp` resolved it. One test-host launch stalled without loading XCTest; restarting the task's simulator resolved that launch issue.
# Typography and Live Activity — October 1, 2026

- Task names and elapsed time use system body text. Both task-section headers use the same title3 semibold style; rows grow with text.
- Replaced the Live Activity timer's unconstrained horizontal sizing with a finite width. Compact Island time is right aligned in a narrower slot.
- All 13 unit and 4 UI tests passed on iPhone 17 Pro / iOS 26. The switching/relaunch flow also passed with Home Screen and expanded Island captures.
- Inspected compact and expanded Island screenshots: content renders, and the compact timer has no extra blank space to its right. Physical-device behavior remains unverified.
- Screenshots: [compact Island](Screenshots/dynamic-island-compact.png), [expanded activity](Screenshots/live-activity-expanded.png).
# Daily clock — October 1, 2026

- Added a bordered 24-hour clock below total tracked time and above task bars. Each tracked minute occupies its local clock arc; task colors match the bars. Untracked time stays dark.
- The four cardinal labels are 00, 06, 12, and 18. VoiceOver describes the clock orientation; the existing bars and timeline provide readable details.
- Timeline entries and gaps now display newest first.
- The full 13 unit / 4 UI test suite passed. Targeted audit and largest-text checks passed after drawing refinements, including the clock's presence and reverse interval ordering.

# Issues 3, 4, and 6 — October 1, 2026

- Added an iOS 26 scheduled Live Activity successor with the original interval ID/start, cancellation of obsolete activities, legacy-activity migration, and foreground replenishment. The queue holds one successor; roughly sixteen hours without interaction is the intended bound, not indefinite renewal. iOS requires an alert for its scheduled start. Older iOS recreates expired presentation on app/widget interaction. No backend or guaranteed background wakeup was added.
- Shared the refined day clock between audit and small/medium Home Screen widgets. Labels sit outside the ring/ticks; a tracked-time total sits inside. Widget timelines derive arcs/totals from persisted intervals and include midnight exactly. The medium widget offers the first three ordered, unarchived tasks, Stop, and All tasks through a LiveActivityIntent and the existing SQLite transactions.
- The full **16 unit + 4 UI tests passed** on iPhone 17 Pro / iOS 26 with Xcode 26.0.1 and ad-hoc simulator signing. Added coverage for scheduled renewal dates/original starts/legacy decoding, independent-store widget switching/stopping/same-task no-op/stale task rejection, and widget midnight rollover. Existing concurrency, history, calendar/DST, audit correction, relaunch, and large-text checks passed.
- Inspected the recorded-history audit screenshot: 06/18 labels clear the ring and ticks, and the tracked total renders inside the clock. Widget extension and App Intent metadata compiled successfully.
- The additional iOS 17 compatibility build compiled, but its UI launch stalled; that runtime test is incomplete. Disk pressure offloaded the synced checkout during verification. All modified sources were recovered and preserved in an unsynced checkout; no files were deleted.
- **Hardware checks remain:** add both widget sizes, tap each switch/Stop with the app terminated, rename/archive/reorder while widgets are visible, observe midnight and time-zone changes, verify disabled Live Activities/system activity limits, and observe the actual scheduled eight-hour handoff and required alert. Simulator tests do not establish those device behaviors.
