import SwiftUI
import WidgetKit

struct DayEntry: TimelineEntry {
    var date: Date
    var state: RecordingState
    var unavailable = false
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), state: RecordingState())
    }

    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        Task { completion(await load()) }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        Task {
            let entry = await load()
            // Recompute live arcs from the saved open interval; never save derived history.
            let dates = WidgetDates.make(now: entry.date)
            completion(Timeline(entries: dates.map {
                DayEntry(date: $0, state: entry.state, unavailable: entry.unavailable)
            }, policy: .after(dates.last!.addingTimeInterval(60))))
        }
    }

    private func load() async -> DayEntry {
        do { return DayEntry(date: Date(), state: try await RecordingStore.shared.snapshot()) }
        catch { return DayEntry(date: Date(), state: RecordingState(), unavailable: true) }
    }
}

struct DayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "FrictionlessDay", provider: DayProvider()) { entry in
            DayWidgetView(entry: entry)
                .containerBackground(Theme.background, for: .widget)
        }
        .configurationDisplayName("Your day")
        .description("Watch your day fill up and tap a task to switch recording.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct DayWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: DayEntry

    var body: some View {
        let audit = DailyAudit.make(state: entry.state, day: entry.date, now: entry.date)
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                if entry.unavailable {
                    Text("Open Frictionless").font(.headline)
                    Text("Saved records are unavailable.").font(.caption)
                } else {
                    DayClock(segments: audit.segments, tasks: entry.state.tasks)
                    Text(activeName).font(.caption.weight(.medium)).lineLimit(1)
                }
            }.frame(maxWidth: .infinity)
            if family == .systemMedium && !entry.unavailable {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(entry.state.visibleTasks.prefix(3))) { task in
                        Button(intent: SwitchRecordingIntent(taskID: task.id.uuidString)) {
                            HStack(spacing: 6) {
                                Circle().fill(Theme.color(task.color)).frame(width: 6, height: 6)
                                Text(task.name).lineLimit(1)
                                Spacer(minLength: 0)
                                if entry.state.active?.taskID == task.id { Image(systemName: "checkmark") }
                            }.font(.caption.weight(.semibold)).padding(.vertical, 5)
                        }.buttonStyle(.plain).accessibilityLabel("Record \(task.name)")
                    }
                    if entry.state.active != nil {
                        Button("Stop", intent: SwitchRecordingIntent(taskID: "stop"))
                            .font(.caption).tint(Theme.banana)
                    }
                    Link("All tasks", destination: URL(string: "frictionless://tasks")!)
                        .font(.caption).foregroundStyle(Theme.banana)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }.foregroundStyle(Theme.text).widgetURL(URL(string: "frictionless://tasks"))
    }

    private var activeName: String {
        if let active = entry.state.active,
           let task = entry.state.tasks.first(where: { $0.id == active.taskID }) { return task.name }
        if entry.state.tasks.isEmpty { return "Add your first task" }
        return "Not recording"
    }
}

#Preview(as: .systemMedium) {
    DayWidget()
} timeline: {
    DayEntry(date: Date(), state: RecordingState())
}
