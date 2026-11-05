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
    var untrackedAt: Date?
    var deletedAt: Date?
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
    var active: RecordedInterval? { intervals.first { $0.end == nil && $0.deletedAt == nil && $0.untrackedAt == nil } }
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
        for interval in state.intervals.filter({ $0.deletedAt == nil }).sorted(by: { $0.start < $1.start }) {
            let start = max(interval.start, lower)
            let end = min(interval.end ?? now, upper)
            guard end > start else { continue }
            if start > cursor {
                segments.append(AuditSegment(id: "gap-\(cursor.timeIntervalSince1970)", start: cursor, end: start))
            }
            segments.append(AuditSegment(id: interval.id.uuidString, interval: interval, start: start, end: end))
            if interval.untrackedAt == nil {
                totals[interval.taskID, default: 0] += end.timeIntervalSince(start)
            }
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

struct WeeklyAudit {
    struct Day: Identifiable {
        var date: Date
        var audit: DailyAudit
        var id: Date { date }
    }
    var start: Date
    var end: Date
    var days: [Day]
    var totals: [UUID: TimeInterval]
    var tracked: TimeInterval { totals.values.reduce(0, +) }

    static func make(state: RecordingState, day: Date, now: Date, calendar: Calendar = .current) -> WeeklyAudit {
        let week = calendar.dateInterval(of: .weekOfYear, for: day)!
        let days = (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: week.start)!
            return Day(date: date, audit: DailyAudit.make(state: state, day: date, now: now, calendar: calendar))
        }
        var totals: [UUID: TimeInterval] = [:]
        for day in days {
            for (id, duration) in day.audit.totals { totals[id, default: 0] += duration }
        }
        return WeeklyAudit(start: week.start, end: week.end, days: days, totals: totals)
    }
}

extension RecordingState {
    func rankedTasks(totals: [UUID: TimeInterval]) -> [TrackedTask] {
        tasks.filter { totals[$0.id, default: 0] > 0 }.sorted {
            let left = totals[$0.id, default: 0]
            let right = totals[$1.id, default: 0]
            if left != right { return left > right }
            if $0.order != $1.order { return $0.order < $1.order }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
