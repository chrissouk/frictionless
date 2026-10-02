import AppIntents
import Foundation

/// LiveActivityIntent executes in the app process and may start ActivityKit presentation.
struct SwitchRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Switch recording"
    static var description = IntentDescription("Record a saved task, or stop tracking.")

    @Parameter(title: "Task identifier") var taskID: String

    init() {}
    init(taskID: String) { self.taskID = taskID }

    func perform() async throws -> some IntentResult {
        _ = try await RecordingAction.apply(taskID: taskID, store: .shared)
        await LiveCoordinator.shared.reconcile()
        return .result()
    }
}

/// Resolve widget input before touching storage, and let the transaction validate stale tasks.
enum RecordingAction {
    static func apply(taskID: String, store: RecordingStore, now: Date? = nil) async throws -> RecordingState {
        var id: UUID?
        if taskID != "stop" {
            guard let parsed = UUID(uuidString: taskID) else {
                throw RecordingError.invalid("This task is no longer available.")
            }
            id = parsed
        }
        return try await store.switchTask(id, now: now)
    }
}
