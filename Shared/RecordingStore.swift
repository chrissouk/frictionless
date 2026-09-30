import Foundation
import SQLite3

/// Each mutation reads and writes inside BEGIN IMMEDIATE. SQLite serializes even
/// independently created stores and extension processes; WAL recovers interrupted writes.
actor RecordingStore {
    static let shared: RecordingStore = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("ui-recording.sqlite")
            if ProcessInfo.processInfo.arguments.contains("--reset-ui-storage") {
                for suffix in ["", "-wal", "-shm"] { try? FileManager.default.removeItem(atPath: url.path + suffix) }
            }
            return RecordingStore(url: url)
        }
        #endif
        return RecordingStore()
    }()
    private let customURL: URL?
    init(url: URL? = nil) { customURL = url }

    private func databaseURL() throws -> URL {
        if let customURL { return customURL }
        guard let group = Bundle.main.object(forInfoDictionaryKey: "RecordingAppGroup") as? String,
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) else {
            throw RecordingError.invalid("Shared storage is unavailable. Check App Group signing for both targets.")
        }
        return directory.appendingPathComponent("recording.sqlite")
    }

    private func connect() throws -> OpaquePointer {
        let url = try databaseURL()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK,
              let db else { throw RecordingError.invalid("Could not open saved records.") }
        sqlite3_busy_timeout(db, 5000)
        do {
            try execute(db, "PRAGMA journal_mode=WAL")
            try execute(db, "PRAGMA synchronous=FULL")
            try execute(db, "CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), payload BLOB NOT NULL)")
            return db
        } catch { sqlite3_close(db); throw error }
    }

    private func execute(_ db: OpaquePointer, _ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw RecordingError.invalid(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func read(_ db: OpaquePointer) throws -> RecordingState {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "SELECT payload FROM state WHERE id=1", -1, &statement, nil) == SQLITE_OK else {
            throw RecordingError.invalid("Could not read records.")
        }
        defer { sqlite3_finalize(statement) }
        let result = sqlite3_step(statement)
        if result == SQLITE_DONE { return RecordingState() }
        guard result == SQLITE_ROW, let bytes = sqlite3_column_blob(statement, 0) else {
            throw RecordingError.invalid("Saved records could not be read. They have been preserved.")
        }
        let data = Data(bytes: bytes, count: Int(sqlite3_column_bytes(statement, 0)))
        return try JSONDecoder().decode(RecordingState.self, from: data)
    }

    private func write(_ state: RecordingState, _ db: OpaquePointer) throws {
        let data = try JSONEncoder().encode(state)
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO state(id,payload) VALUES(1,?)", -1, &statement, nil) == SQLITE_OK else {
            throw RecordingError.invalid("Could not prepare save.")
        }
        defer { sqlite3_finalize(statement) }
        let result = data.withUnsafeBytes { bytes in
            sqlite3_bind_blob(statement, 1, bytes.baseAddress, Int32(data.count), unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        }
        guard result == SQLITE_OK, sqlite3_step(statement) == SQLITE_DONE else {
            throw RecordingError.invalid("Could not save the change. Please try again.")
        }
    }

    func snapshot() throws -> RecordingState {
        let db = try connect()
        defer { sqlite3_close(db) }
        let state = try read(db)
        try validate(state)
        return state
    }

    private func mutate(_ body: (inout RecordingState) throws -> Bool) throws -> RecordingState {
        let db = try connect()
        defer { sqlite3_close(db) }
        try execute(db, "BEGIN IMMEDIATE")
        do {
            var state = try read(db)
            if try body(&state) {
                state.revision += 1
                try validate(state)
                try write(state, db)
            }
            try execute(db, "COMMIT")
            return state
        } catch {
            try? execute(db, "ROLLBACK")
            throw error
        }
    }

    func switchTask(_ id: UUID?, now: Date = Date()) throws -> RecordingState {
        try mutate { state in
            if let id {
                guard state.tasks.contains(where: { $0.id == id && !$0.archived }) else {
                    throw RecordingError.invalid("This task is no longer available.")
                }
            }
            if state.active?.taskID == id { return false }
            let previous = state.intervals
            if let index = state.intervals.firstIndex(where: { $0.end == nil }) {
                guard now >= state.intervals[index].start else {
                    throw RecordingError.invalid("The clock is earlier than the current recording. Correct its start first.")
                }
                state.intervals[index].end = now
            }
            if let id { state.intervals.append(RecordedInterval(taskID: id, start: now)) }
            state.undo = UndoRecord(token: UUID(), revision: state.revision + 1, expires: now.addingTimeInterval(8), intervals: previous)
            return true
        }
    }

    func undo(_ token: UUID, now: Date = Date()) throws -> RecordingState {
        try mutate { state in
            guard let undo = state.undo, undo.token == token, undo.revision == state.revision, now <= undo.expires else {
                throw RecordingError.invalid("Undo expired because time passed or another change was saved.")
            }
            state.intervals = undo.intervals
            state.undo = nil
            return true
        }
    }

    func saveTask(id: UUID? = nil, name: String, color: Int? = nil, shortcut: Bool? = nil) throws -> RecordingState {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw RecordingError.invalid("Enter a task name.") }
        return try mutate { state in
            if let id, let index = state.tasks.firstIndex(where: { $0.id == id }) {
                state.tasks[index].name = trimmed
                if let color { state.tasks[index].color = color }
                if let shortcut { state.tasks[index].shortcut = shortcut }
            } else {
                let count = state.tasks.count
                let shortcuts = state.visibleTasks.filter(\.shortcut).count
                state.tasks.append(TrackedTask(name: trimmed, color: color ?? count % 6, order: count, shortcut: shortcuts < 3))
            }
            guard state.visibleTasks.filter(\.shortcut).count <= 3 else {
                throw RecordingError.invalid("Choose up to three Live Activity shortcuts.")
            }
            state.undo = nil
            return true
        }
    }

    func archive(_ id: UUID, now: Date = Date()) throws -> RecordingState {
        try mutate { state in
            guard let index = state.tasks.firstIndex(where: { $0.id == id }) else { return false }
            if let active = state.intervals.firstIndex(where: { $0.taskID == id && $0.end == nil }) {
                guard now >= state.intervals[active].start else { throw RecordingError.invalid("Correct the recording start before archiving.") }
                state.intervals[active].end = now
            }
            state.tasks[index].archived = true
            state.tasks[index].shortcut = false
            state.undo = nil
            return true
        }
    }

    func reorder(_ ids: [UUID]) throws -> RecordingState {
        try mutate { state in
            guard Set(ids) == Set(state.visibleTasks.map(\.id)), ids.count == Set(ids).count else {
                throw RecordingError.invalid("The task list changed. Try reordering again.")
            }
            for (order, id) in ids.enumerated() {
                if let index = state.tasks.firstIndex(where: { $0.id == id }) { state.tasks[index].order = order }
            }
            state.undo = nil
            return true
        }
    }

    func correct(id: UUID, taskID: UUID, start: Date, end: Date?, now: Date = Date(), previousID: UUID? = nil) throws -> RecordingState {
        try mutate { state in
            guard let index = state.intervals.firstIndex(where: { $0.id == id }),
                  state.tasks.contains(where: { $0.id == taskID }) else { throw RecordingError.invalid("Record not found.") }
            let original = state.intervals[index]
            if original.taskID != taskID && state.tasks.contains(where: { $0.id == taskID && $0.archived }) {
                throw RecordingError.invalid("Choose an available task.")
            }
            guard start <= now, (end ?? now) <= now else { throw RecordingError.invalid("Recorded time cannot be in the future.") }
            if original.end != nil && end == nil { throw RecordingError.invalid("A finished record must have an end time.") }
            if let previousID {
                guard let previousIndex = state.intervals.firstIndex(where: { $0.id == previousID }),
                      previousID != id, state.intervals[previousIndex].end == original.start else {
                    throw RecordingError.invalid("The previous boundary changed. Reload this correction.")
                }
                state.intervals[previousIndex].end = start
            }
            state.intervals[index] = RecordedInterval(id: id, taskID: taskID, start: start, end: end)
            state.undo = nil
            return true
        }
    }

    private func validate(_ state: RecordingState) throws {
        guard state.intervals.filter({ $0.end == nil }).count <= 1 else { throw RecordingError.invalid("Multiple open records detected. Saved history has been preserved.") }
        var previousEnd: Date?
        var previousWasOpen = false
        let sorted = state.intervals.sorted { left, right in
            if left.start != right.start { return left.start < right.start }
            if left.end == nil { return false }
            if right.end == nil { return true }
            return left.end! < right.end!
        }
        for interval in sorted {
            guard state.tasks.contains(where: { $0.id == interval.taskID }) else { throw RecordingError.invalid("A record refers to a missing task.") }
            if let end = interval.end, end < interval.start { throw RecordingError.invalid("End must be after start.") }
            if previousWasOpen { throw RecordingError.invalid("This correction overlaps another record.") }
            if let previousEnd, interval.start < previousEnd { throw RecordingError.invalid("This correction overlaps another record.") }
            previousEnd = interval.end
            previousWasOpen = interval.end == nil
        }
    }
}
