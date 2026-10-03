import Foundation

enum FruitPalette {
    static let names = ["Banana", "Blueberry", "Peach", "Grape", "Pear", "Apple", "Orange"]
}

struct TrackedTask: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var color: Int
    var order: Int
    var archived = false
}

struct RecordedInterval: Codable, Identifiable, Equatable {
    var id = UUID()
    var taskID: UUID
    var start: Date
    var end: Date?
}

struct UndoRecord: Codable {
    var token: UUID
    var revision: Int
    var expires: Date
    var intervals: [RecordedInterval]
}

struct RecordingState: Codable {
    var tasks: [TrackedTask] = []
    var intervals: [RecordedInterval] = []
    var revision = 0
    var undo: UndoRecord?
    var active: RecordedInterval? { intervals.first { $0.end == nil } }
    var visibleTasks: [TrackedTask] {
        tasks.filter { !$0.archived }.sorted { $0.order < $1.order }
    }
}

enum RecordingError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return message
        }
    }
}

struct AuditSegment: Identifiable {
    var id: String
    var interval: RecordedInterval?
    var start: Date
    var end: Date
    var duration: TimeInterval { end.timeIntervalSince(start) }
}

struct DailyAudit {
    var segments: [AuditSegment]
    var totals: [UUID: TimeInterval]
    var tracked: TimeInterval { totals.values.reduce(0, +) }

    static func make(state: RecordingState, day: Date, now: Date, calendar: Calendar = .current) -> DailyAudit {
        let lower = calendar.startOfDay(for: day)
        let next = calendar.date(byAdding: .day, value: 1, to: lower)!
        let upper = min(next, now)
        guard upper > lower else { return DailyAudit(segments: [], totals: [:]) }
        var cursor = lower
        var segments: [AuditSegment] = []
        var totals: [UUID: TimeInterval] = [:]
        for interval in state.intervals.sorted(by: { $0.start < $1.start }) {
            let start = max(interval.start, lower)
            let end = min(interval.end ?? now, upper)
            guard end > start else { continue }
            if start > cursor {
                segments.append(AuditSegment(id: "gap-\(cursor.timeIntervalSince1970)", start: cursor, end: start))
            }
            segments.append(AuditSegment(id: interval.id.uuidString, interval: interval, start: start, end: end))
            totals[interval.taskID, default: 0] += end.timeIntervalSince(start)
            cursor = end
        }
        if cursor < upper {
            segments.append(AuditSegment(id: "gap-\(cursor.timeIntervalSince1970)", start: cursor, end: upper))
        }
        return DailyAudit(segments: segments, totals: totals)
    }
}

func durationLabel(_ seconds: TimeInterval) -> String {
    if seconds <= 0 { return "0m" }
    let minutes = max(0, Int(seconds / 60))
    if minutes == 0 { return "<1m" }
    if minutes < 60 { return "\(minutes)m" }
    return "\(minutes / 60)h \(minutes % 60)m"
}

/// Include midnight exactly so the next calendar day's clock starts empty.
enum WidgetDates {
    static func make(now: Date, calendar: Calendar = .current) -> [Date] {
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
        var dates = (0..<60).map { now.addingTimeInterval(Double($0) * 60) }
        if midnight <= dates.last!, !dates.contains(midnight) { dates.append(midnight) }
        return dates.sorted()
    }
}
