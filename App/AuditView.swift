import SwiftUI

struct AuditView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var editing: RecordedInterval?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 30)) { context in
                let audit = DailyAudit.make(state: model.state, day: day, now: context.date)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Button("Previous day", systemImage: "chevron.left") { shiftDay(-1) }
                                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            Spacer()
                            Text(day, format: .dateTime.month(.abbreviated).day().year()).font(.headline)
                            Spacer()
                            Button("Next day", systemImage: "chevron.right") { shiftDay(1) }
                                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                                .disabled(Calendar.current.isDateInToday(day))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(durationLabel(audit.tracked)).font(.largeTitle.weight(.semibold))
                            Text("Total tracked time").foregroundStyle(.secondary)
                        }
                        DayClock(segments: audit.segments, tasks: model.state.tasks)
                        if audit.totals.isEmpty { Text("No recorded time for this day.").foregroundStyle(.secondary) }
                        ForEach(model.state.tasks.filter { audit.totals[$0.id] != nil }.sorted { $0.order < $1.order }) { task in
                            let total = audit.totals[task.id, default: 0]
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(task.name); Spacer(); Text(durationLabel(total)).foregroundStyle(.secondary) }
                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: 3).fill(Theme.color(task.color))
                                        .frame(width: max(3, geometry.size.width * total / max(audit.tracked, 1)))
                                }.frame(height: 8).accessibilityHidden(true)
                            }.accessibilityElement(children: .combine)
                        }
                        Text("Timeline").font(.title2.weight(.medium)).padding(.top, 8)
                        ForEach(audit.segments.reversed()) { segment in
                            if let interval = segment.interval {
                                let taskName = model.state.tasks.first { $0.id == interval.taskID }?.name ?? "Task"
                                Button { editing = interval } label: { segmentRow(segment) }
                                    .accessibilityIdentifier("interval-\(taskName)")
                                    .buttonStyle(.plain).accessibilityHint("Edit task or recording times")
                            } else { segmentRow(segment) }
                            Divider()
                        }
                    }.padding(24)
                }.background(Theme.background).foregroundStyle(Theme.text)
            }.navigationTitle("Daily audit").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $editing) { IntervalEditorView(interval: $0) }
        }
    }

    private func shiftDay(_ value: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: value, to: day) { day = next }
    }

    private func segmentRow(_ segment: AuditSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let interval = segment.interval, let task = model.state.tasks.first(where: { $0.id == interval.taskID }) {
                    Image(systemName: "circle.fill").font(.caption2).foregroundStyle(Theme.color(task.color))
                    Text(task.name).font(.headline)
                    if interval.end == nil { Text("Recording").font(.caption).foregroundStyle(Theme.mint) }
                } else {
                    Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                    Text("Untracked").foregroundStyle(.secondary)
                }
                Spacer()
                Text(durationLabel(segment.duration)).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text(segment.start, format: .dateTime.hour().minute())
                Text("–")
                Text(segment.end, format: .dateTime.hour().minute())
            }.font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).contentShape(Rectangle())
    }
}
