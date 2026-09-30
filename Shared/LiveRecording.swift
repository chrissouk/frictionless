import ActivityKit
import AppIntents
import Foundation

struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var name: String
        var color: Int
        var start: Date
        var shortcuts: [Shortcut]
    }
    struct Shortcut: Codable, Hashable, Identifiable {
        var id: String
        var name: String
    }
    var intervalID: String
}

/// Queue presentation work across suspension points. Always consult the saved
/// state; presentation errors never undo a successful database transaction.
actor LiveCoordinator {
    static let shared = LiveCoordinator()
    private var tail: Task<String?, Never>?

    func reconcile() async -> String? {
        let prior = tail
        let job = Task {
            _ = await prior?.value
            return await Self.refresh()
        }
        tail = job
        return await job.value
    }

    private static func refresh() async -> String? {
        do {
            let state = try await RecordingStore.shared.snapshot()
            guard let active = state.active,
                  let task = state.tasks.first(where: { $0.id == active.taskID }) else {
                for activity in Activity<RecordingAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                return nil
            }
            let content = RecordingAttributes.ContentState(
                name: task.name, color: task.color, start: active.start,
                shortcuts: state.visibleTasks.filter(\.shortcut).prefix(3).map {
                    RecordingAttributes.Shortcut(id: $0.id.uuidString, name: $0.name)
                })
            let activities = Activity<RecordingAttributes>.activities
            if activities.count == 1, let existing = activities.first,
               existing.attributes.intervalID == active.id.uuidString,
               existing.activityState == .active {
                await existing.update(ActivityContent(state: content, staleDate: nil))
                return nil
            }
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return "Live Activities are disabled. Recording is saved." }
            _ = try Activity.request(attributes: RecordingAttributes(intervalID: active.id.uuidString), content: ActivityContent(state: content, staleDate: nil), pushType: nil)
            return nil
        } catch {
            return "Recording is saved. Live Activity unavailable: \(error.localizedDescription)"
        }
    }
}

struct SwitchTaskIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Switch recorded task"
    static var openAppWhenRun = false
    @Parameter(title: "Task identifier") var taskID: String
    init() {}
    init(taskID: String) { self.taskID = taskID }
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: taskID) else { throw RecordingError.invalid("Task unavailable.") }
        _ = try await RecordingStore.shared.switchTask(id)
        _ = await LiveCoordinator.shared.reconcile()
        return .result()
    }
}

struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop tracking"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        _ = try await RecordingStore.shared.switchTask(nil)
        _ = await LiveCoordinator.shared.reconcile()
        return .result()
    }
}
