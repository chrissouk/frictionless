import ActivityKit
import Foundation
import OSLog

struct RecordingAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var name: String
        var color: Int
        var start: Date

        static func make(state: RecordingState) -> Self? {
            guard let active = state.active,
                  let task = state.tasks.first(where: { $0.id == active.taskID }) else { return nil }
            return Self(name: String(String.UnicodeScalarView(task.name.unicodeScalars.prefix(80))),
                        color: task.color, start: active.start)
        }
    }
    var intervalID: String
}

/// Presentation errors never undo a successful database transaction.
actor LiveCoordinator {
    static let shared = LiveCoordinator()
    private var tail: Task<Void, Never>?
    private static let logger = Logger(subsystem: "frictionless", category: "activity")

    func reconcile() async {
        let prior = tail
        let job = Task {
            await prior?.value
            await Self.refresh()
        }
        tail = job
        await job.value
    }

    private static func refresh() async {
        do {
            let state = try await RecordingStore.shared.snapshot()
            let activities = Activity<RecordingAttributes>.activities
            guard let active = state.active,
                  let content = RecordingAttributes.ContentState.make(state: state) else {
                for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
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
