import ActivityKit
import AppIntents
import Foundation
import OSLog

struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var name: String
        var color: Int
        var start: Date
        var tasks: [TaskButton]
        var page: Int
        var pageCount: Int

        static func make(state: RecordingState, page requestedPage: Int = 0) -> Self? {
            guard let active = state.active,
                  let task = state.tasks.first(where: { $0.id == active.taskID }) else { return nil }
            let tasks = state.visibleTasks
            // Send only the displayed page to stay within ActivityKit's payload and height budget.
            let pageCount = max(1, (tasks.count + 1) / 2)
            let page = min(max(0, requestedPage), pageCount - 1)
            return Self(
                name: displayName(task.name), color: task.color, start: active.start,
                tasks: tasks.dropFirst(page * 2).prefix(2).map {
                    TaskButton(id: $0.id.uuidString, name: displayName($0.name))
                }, page: page, pageCount: pageCount)
        }

        private static func displayName(_ name: String) -> String {
            String(String.UnicodeScalarView(name.unicodeScalars.prefix(80)))
        }
    }
    struct TaskButton: Codable, Hashable, Identifiable {
        var id: String
        var name: String
    }
    var intervalID: String
}

extension RecordingAttributes.ContentState {
    // An activity from the previous app version can be refreshed in place.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        name = try values.decode(String.self, forKey: .name)
        color = try values.decode(Int.self, forKey: .color)
        start = try values.decode(Date.self, forKey: .start)
        tasks = try values.decodeIfPresent([RecordingAttributes.TaskButton].self, forKey: .tasks) ?? []
        page = try values.decodeIfPresent(Int.self, forKey: .page) ?? 0
        pageCount = try values.decodeIfPresent(Int.self, forKey: .pageCount) ?? 1
    }
}

/// Queue presentation work across suspension points. Always consult the saved
/// state; presentation errors never undo a successful database transaction.
actor LiveCoordinator {
    static let shared = LiveCoordinator()
    private var tail: Task<Void, Never>?
    private static let logger = Logger(subsystem: "frictionless", category: "activity")

    func reconcile(page: Int? = nil) async {
        let prior = tail
        let job = Task {
            await prior?.value
            await Self.refresh(page: page)
        }
        tail = job
        await job.value
    }

    private static func refresh(page: Int?) async {
        do {
            let state = try await RecordingStore.shared.snapshot()
            let activities = Activity<RecordingAttributes>.activities
            let requestedPage = page ?? activities.first?.content.state.page ?? 0
            guard let active = state.active,
                  let content = RecordingAttributes.ContentState.make(state: state, page: requestedPage) else {
                for activity in Activity<RecordingAttributes>.activities {
                    await activity.end(nil, dismissalPolicy: .immediate)
                }
                return
            }
            if activities.count == 1, let existing = activities.first,
               existing.attributes.intervalID == active.id.uuidString,
               existing.activityState == .active {
                await existing.update(ActivityContent(state: content, staleDate: nil))
                return
            }
            for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            _ = try Activity.request(attributes: RecordingAttributes(intervalID: active.id.uuidString), content: ActivityContent(state: content, staleDate: nil), pushType: nil)
        } catch {
            logger.error("Activity refresh failed: \(error.localizedDescription, privacy: .public)")
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
        await LiveCoordinator.shared.reconcile()
        return .result()
    }
}

struct StopRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Stop tracking"
    static var openAppWhenRun = false
    func perform() async throws -> some IntentResult {
        _ = try await RecordingStore.shared.switchTask(nil)
        await LiveCoordinator.shared.reconcile()
        return .result()
    }
}

struct TaskPageIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Show tasks"
    static var openAppWhenRun = false
    @Parameter(title: "Page") var page: Int
    init() {}
    init(page: Int) { self.page = page }
    func perform() async throws -> some IntentResult {
        await LiveCoordinator.shared.reconcile(page: page)
        return .result()
    }
}
