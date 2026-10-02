import ActivityKit
import Foundation
import OSLog
import WidgetKit

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
    var presentationStart: Date? = nil
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
            WidgetCenter.shared.reloadAllTimelines()
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
            guard ActivityAuthorizationInfo().areActivitiesEnabled else {
                for activity in activities { await activity.end(nil, dismissalPolicy: .immediate) }
                return
            }
            let matching = activities.filter { $0.attributes.intervalID == active.id.uuidString }
            var current = matching.filter { $0.activityState == .active }.max {
                ($0.attributes.presentationStart ?? .distantPast) < ($1.attributes.presentationStart ?? .distantPast)
            }
            var pending: Activity<RecordingAttributes>?
            if #available(iOS 26.0, *) {
                pending = matching.first { $0.activityState == .pending }
            }
            for activity in activities where activity.id != current?.id && activity.id != pending?.id {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            // Upgrade activities created before scheduling metadata existed once.
            if #available(iOS 26.0, *), let legacy = current, legacy.attributes.presentationStart == nil {
                await legacy.end(nil, dismissalPolicy: .immediate)
                current = nil
            }
            if current == nil {
                if let pending { await pending.end(nil, dismissalPolicy: .immediate) }
                pending = nil
                current = try Activity.request(
                    attributes: RecordingAttributes(intervalID: active.id.uuidString, presentationStart: Date()),
                    content: ActivityContent(state: content, staleDate: nil), pushType: nil)
            }
            if let current { await current.update(ActivityContent(state: content, staleDate: nil)) }
            if let pending { await pending.update(ActivityContent(state: content, staleDate: nil)) }
            // iOS owns the scheduled start; no background timer or database mutation is needed.
            if #available(iOS 26.0, *), pending == nil, let current,
               let started = current.attributes.presentationStart {
                let renewal = ActivityRenewal.nextStart(presentationStart: started, now: Date())
                _ = try Activity.request(
                    attributes: RecordingAttributes(intervalID: active.id.uuidString, presentationStart: renewal),
                    content: ActivityContent(state: content, staleDate: nil), pushType: nil, style: .standard,
                    alertConfiguration: AlertConfiguration(title: "Still recording", body: "Your task timer continues.", sound: .default),
                    start: renewal)
            }
        } catch {
            logger.error("Activity refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

/// A small overlap avoids deliberately scheduling after the system's eight-hour expiry.
enum ActivityRenewal {
    static let lifetime: TimeInterval = 8 * 60 * 60
    static func nextStart(presentationStart: Date, now: Date) -> Date {
        max(presentationStart.addingTimeInterval(lifetime - 60), now.addingTimeInterval(5))
    }
}
