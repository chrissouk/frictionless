import XCTest
import SQLite3
@testable import Frictionless

final class RecordingTests: XCTestCase {
    private var directory: URL!
    private var store: RecordingStore!
    private let epoch = Date(timeIntervalSince1970: 1_700_000_000)

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        store = RecordingStore(url: directory.appendingPathComponent("test.sqlite"))
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    private func tasks() async throws -> [TrackedTask] {
        _ = try await store.saveTask(name: "Work")
        return try await store.saveTask(name: "Rest").visibleTasks
    }

    func testProductionAppGroupStorageCanOpen() async throws {
        let state = try await RecordingStore.shared.snapshot()
        XCTAssertLessThanOrEqual(state.intervals.filter { $0.end == nil }.count, 1)
    }

    func testStartSwitchSameTaskStopAndRelaunch() async throws {
        let tasks = try await tasks()
        var state = try await store.switchTask(tasks[0].id, now: epoch)
        XCTAssertEqual(state.intervals.count, 1)
        let revision = state.revision
        state = try await store.switchTask(tasks[0].id, now: epoch.addingTimeInterval(10))
        XCTAssertEqual(state.revision, revision)
        state = try await store.switchTask(tasks[1].id, now: epoch.addingTimeInterval(60))
        XCTAssertEqual(state.intervals[0].end, state.active?.start)
        let reopened = RecordingStore(url: directory.appendingPathComponent("test.sqlite"))
        let saved = try await reopened.snapshot()
        XCTAssertEqual(saved.active?.taskID, tasks[1].id)
        state = try await reopened.switchTask(nil, now: epoch.addingTimeInterval(120))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.intervals.count, 2)
    }

    func testIndependentStoresConcurrentSwitches() async throws {
        let tasks = try await tasks()
        let url = directory.appendingPathComponent("test.sqlite")
        try await withThrowingTaskGroup(of: Void.self) { group in
            for index in 0..<30 {
                group.addTask {
                    let independent = RecordingStore(url: url)
                    _ = try await independent.switchTask(tasks[index % 2].id, now: self.epoch)
                }
            }
            try await group.waitForAll()
        }
        let state = try await store.snapshot()
        XCTAssertEqual(state.intervals.filter { $0.end == nil }.count, 1)
        let sorted = state.intervals.sorted { $0.start < $1.start }
        XCTAssertTrue(sorted.allSatisfy { ($0.end ?? self.epoch) >= $0.start })
    }

    func testUndoRestoresPreviousStateAndRejectsLaterChange() async throws {
        let tasks = try await tasks()
        _ = try await store.switchTask(tasks[0].id, now: epoch)
        let switched = try await store.switchTask(tasks[1].id, now: epoch.addingTimeInterval(60))
        let token = try XCTUnwrap(switched.undo?.token)
        let undone = try await store.undo(token, now: epoch.addingTimeInterval(61))
        XCTAssertEqual(undone.active?.taskID, tasks[0].id)
        XCTAssertEqual(undone.active?.start, epoch)
        let next = try await store.switchTask(tasks[1].id, now: epoch.addingTimeInterval(70))
        _ = try await store.saveTask(id: tasks[0].id, name: "Renamed")
        do { _ = try await store.undo(try XCTUnwrap(next.undo?.token), now: epoch.addingTimeInterval(71)); XCTFail("Unsafe undo accepted") }
        catch { XCTAssertNotNil(error as? RecordingError) }
    }

    func testUndoExpiresAndFirstStartCanUndo() async throws {
        let tasks = try await tasks()
        let first = try await store.switchTask(tasks[0].id, now: epoch)
        let undone = try await store.undo(try XCTUnwrap(first.undo?.token), now: epoch.addingTimeInterval(1))
        XCTAssertTrue(undone.intervals.isEmpty)
        let next = try await store.switchTask(tasks[0].id, now: epoch)
        do { _ = try await store.undo(try XCTUnwrap(next.undo?.token), now: epoch.addingTimeInterval(9)); XCTFail("Expired undo accepted") }
        catch { XCTAssertNotNil(error as? RecordingError) }
    }

    func testCorrectionsRejectOverlapAndAllowSharedBoundary() async throws {
        let tasks = try await tasks()
        _ = try await store.switchTask(tasks[0].id, now: epoch)
        let state = try await store.switchTask(tasks[1].id, now: epoch.addingTimeInterval(60))
        let active = try XCTUnwrap(state.active)
        do {
            _ = try await store.correct(id: active.id, taskID: tasks[1].id, start: epoch.addingTimeInterval(30), end: nil, now: epoch.addingTimeInterval(120))
            XCTFail("Overlap accepted")
        } catch { XCTAssertNotNil(error as? RecordingError) }
        let saved = try await store.correct(id: active.id, taskID: tasks[1].id, start: epoch.addingTimeInterval(30), end: nil, now: epoch.addingTimeInterval(120), previousID: state.intervals[0].id)
        XCTAssertEqual(saved.intervals[0].end, saved.active?.start)
        do {
            _ = try await store.correct(id: active.id, taskID: tasks[1].id, start: epoch.addingTimeInterval(30), end: epoch, now: epoch.addingTimeInterval(120))
            XCTFail("Negative duration accepted")
        } catch { XCTAssertNotNil(error as? RecordingError) }
        let unchanged = try await store.snapshot()
        XCTAssertEqual(unchanged.active?.start, epoch.addingTimeInterval(30))
    }

    func testArchiveStopsAndPreservesHistory() async throws {
        let tasks = try await tasks()
        _ = try await store.switchTask(tasks[0].id, now: epoch)
        let state = try await store.archive(tasks[0].id, now: epoch.addingTimeInterval(60))
        XCTAssertNil(state.active)
        XCTAssertEqual(state.intervals.count, 1)
        do { _ = try await store.switchTask(tasks[0].id, now: epoch.addingTimeInterval(70)); XCTFail("Archived task started") }
        catch { XCTAssertNotNil(error as? RecordingError) }
    }

    func testInterruptedTransactionDoesNotEraseSavedHistory() async throws {
        let tasks = try await tasks()
        _ = try await store.switchTask(tasks[0].id, now: epoch)
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(directory.appendingPathComponent("test.sqlite").path, &db), SQLITE_OK)
        XCTAssertEqual(sqlite3_exec(db, "BEGIN IMMEDIATE; DELETE FROM state;", nil, nil, nil), SQLITE_OK)
        sqlite3_close(db) // Uncommitted write rolls back, as with process interruption.
        let state = try await RecordingStore(url: directory.appendingPathComponent("test.sqlite")).snapshot()
        XCTAssertEqual(state.active?.taskID, tasks[0].id)
    }

    func testMidnightClippingAndActiveTotals() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 30))!
        let task = TrackedTask(name: "Sleep", color: 0, order: 0)
        let interval = RecordedInterval(taskID: task.id, start: day.addingTimeInterval(-3600), end: day.addingTimeInterval(7200))
        let state = RecordingState(tasks: [task], intervals: [interval])
        let audit = DailyAudit.make(state: state, day: day, now: day.addingTimeInterval(86400), calendar: calendar)
        XCTAssertEqual(audit.tracked, 7200)
        XCTAssertEqual(audit.segments.last?.interval, nil)
        let activeState = RecordingState(tasks: [task], intervals: [RecordedInterval(taskID: task.id, start: day)])
        XCTAssertEqual(DailyAudit.make(state: activeState, day: day, now: day.addingTimeInterval(1800), calendar: calendar).tracked, 1800)
        XCTAssertEqual(state.intervals[0].start, interval.start)
    }

    func testDaylightSavingDaysHaveActualCalendarDuration() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let task = TrackedTask(name: "Sleep", color: 0, order: 0)
        for (month, dayNumber, hours) in [(3, 8, 23), (11, 1, 25)] {
            let day = calendar.date(from: DateComponents(year: 2026, month: month, day: dayNumber))!
            let end = calendar.date(byAdding: .day, value: 1, to: day)!
            let state = RecordingState(tasks: [task], intervals: [RecordedInterval(taskID: task.id, start: day.addingTimeInterval(-3600), end: end.addingTimeInterval(3600))])
            XCTAssertEqual(DailyAudit.make(state: state, day: day, now: end.addingTimeInterval(3600), calendar: calendar).tracked, Double(hours * 3600))
        }
    }
}
