import SwiftUI

struct AuditView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var weekly = false
    @State private var editing: RecordedInterval?
    @State private var showDeleted = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 30)) { context in
                let audit = DailyAudit.make(state: model.state, day: day, now: context.date)
                let week = WeeklyAudit.make(state: model.state, day: day, now: context.date)
                List {
                    Section {
                        Picker("Summary period", selection: $weekly) {
                            Text("Day").tag(false)
                            Text("Week").tag(true)
                        }.pickerStyle(.segmented)
                        dateNavigation(week: week)
                            .accessibilityHint("Swipe left or right to browse dates")
                            .contentShape(Rectangle())
                            .gesture(DragGesture(minimumDistance: 35).onEnded { value in
                                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                                if value.translation.width > 0 { shift(-1) }
                                else { shift(1) }
                            })
                        if weekly {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(durationLabel(week.tracked)).font(.largeTitle.weight(.semibold))
                                Text("Tracked this week").font(.subheadline).foregroundStyle(.secondary)
                            }.padding(.vertical, 12)
                            weekChart(week, now: context.date)
                        } else {
                            DayClock(segments: audit.segments, tasks: model.state.tasks).frame(height: 240)
                        }
                    }.listRowSeparator(.hidden).listRowBackground(Color.clear)
                    if weekly {
                        totals(week.totals)
                    } else {
                        totals(audit.totals)
                        Section("Timeline") {
                            ForEach(audit.segments.reversed()) { segment in
                                if let interval = segment.interval {
                                    Button { editing = interval } label: { segmentRow(segment) }
                                        .buttonStyle(.plain)
                                        .accessibilityIdentifier("interval-\(eventName(interval))")
                                        .accessibilityHint("Edit event. Swipe left for Delete or right for Untracked.")
                                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                            Button("Delete", systemImage: "trash") { remove(interval) }.tint(.red)
                                        }
                                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                            if interval.untrackedAt == nil {
                                                Button("Untracked", systemImage: "circle.dashed") { untrack(interval) }.tint(.gray)
                                            }
                                        }
                                } else { segmentRow(segment) }
                            }.listRowBackground(Color.clear)
                        }
                    }
                }.listStyle(.plain).textCase(nil).scrollContentBackground(.hidden)
                    .background(Theme.background).foregroundStyle(Theme.text)
            }.navigationTitle(navigationTitle).navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Recently deleted", systemImage: "clock.arrow.circlepath") { showDeleted = true }
                            .labelStyle(.iconOnly)
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
                .sheet(item: $editing) { IntervalEditorView(interval: $0) }
                .sheet(isPresented: $showDeleted) { deletedEvents }
        }
    }

    private func dateNavigation(week: WeeklyAudit) -> some View {
        HStack {
            Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 44, height: 44) }
                .accessibilityLabel(previousLabel)
            Spacer(minLength: 0)
            VStack(spacing: 4) {
                if weekly {
                    Text(week.start, format: .dateTime.month(.abbreviated).day()) + Text(" – ") +
                    Text(Calendar.current.date(byAdding: .day, value: -1, to: week.end)!, format: .dateTime.month(.abbreviated).day().year())
                } else {
                    Text(day, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
                }
                if !Calendar.current.isDateInToday(day) {
                    Button("Back to today") { day = Date() }.font(.caption)
                }
            }.font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
            Spacer(minLength: 0)
            Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 44, height: 44) }
                .accessibilityLabel(nextLabel).disabled(!canAdvance)
        }.buttonStyle(.plain)
    }

    private var navigationTitle: String {
        if weekly { return "Weekly summary" }
        return "Daily audit"
    }
    private var previousLabel: String {
        if weekly { return "Previous week" }
        return "Previous day"
    }
    private var nextLabel: String {
        if weekly { return "Next week" }
        return "Next day"
    }
    private var canAdvance: Bool {
        let calendar = Calendar.current
        if weekly {
            return calendar.dateInterval(of: .weekOfYear, for: day)!.end <= Date()
        }
        return calendar.startOfDay(for: day) < calendar.startOfDay(for: Date())
    }
    private func shift(_ value: Int) {
        if value > 0 && !canAdvance { return }
        var amount = value
        if weekly { amount *= 7 }
        if let next = Calendar.current.date(byAdding: .day, value: amount, to: day) {
            withAnimation(.easeInOut(duration: 0.2)) { day = min(next, Date()) }
        }
    }

    private func weekChart(_ week: WeeklyAudit, now: Date) -> some View {
        let peak = max(week.days.map { $0.audit.tracked }.max() ?? 0, 1)
        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(week.days) { entry in
                Button {
                    day = entry.date
                    weekly = false
                } label: {
                    VStack(spacing: 8) {
                        VStack {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 5).fill(Theme.banana)
                                .frame(height: max(2, 88 * entry.audit.tracked / peak))
                        }.frame(height: 88)
                        Text(entry.date, format: .dateTime.weekday(.narrow)).font(.caption)
                    }.frame(maxWidth: .infinity)
                }.buttonStyle(.plain).disabled(entry.date > now)
                    .accessibilityLabel(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .accessibilityValue(durationLabel(entry.audit.tracked))
                    .accessibilityHint("Show this day")
            }
        }.padding(.vertical, 12)
    }

    private func totals(_ values: [UUID: TimeInterval]) -> some View {
        Section("Time by task") {
            if values.isEmpty { Text("No recorded time yet.").foregroundStyle(.secondary) }
            ForEach(model.state.rankedTasks(totals: values)) { task in
                HStack(spacing: 12) {
                    Circle().fill(Theme.color(task.color)).frame(width: 8, height: 8)
                    Text(task.name)
                    Spacer()
                    Text(durationLabel(values[task.id, default: 0])).monospacedDigit().foregroundStyle(.secondary)
                }.padding(.vertical, 6).accessibilityElement(children: .combine)
            }
        }.listRowBackground(Color.clear)
    }

    private func eventName(_ interval: RecordedInterval) -> String {
        if interval.untrackedAt != nil { return "Untracked" }
        return model.state.tasks.first { $0.id == interval.taskID }?.name ?? "Task"
    }
    private func segmentRow(_ segment: AuditSegment) -> some View {
        HStack(spacing: 12) {
            if let interval = segment.interval, interval.untrackedAt == nil,
               let task = model.state.tasks.first(where: { $0.id == interval.taskID }) {
                Capsule().fill(Theme.color(task.color)).frame(width: 3)
            }
            VStack(alignment: .leading, spacing: 6) {
                if let interval = segment.interval { Text(eventName(interval)).font(.body.weight(.medium)) }
                else { Text("Untracked").foregroundStyle(.secondary) }
                HStack(spacing: 4) {
                    Text(segment.start, format: .dateTime.hour().minute())
                    Text("–")
                    Text(segment.end, format: .dateTime.hour().minute())
                    if segment.interval?.end == nil && segment.interval != nil { Text("· Now") }
                }.font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(durationLabel(segment.duration)).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
        }.frame(minHeight: 56).padding(.vertical, 4).contentShape(Rectangle())
    }
    private func remove(_ interval: RecordedInterval) {
        Task { _ = await model.perform { try await model.store.removeInterval(interval.id) } }
    }
    private func untrack(_ interval: RecordedInterval) {
        Task { _ = await model.perform { try await model.store.markUntracked(interval.id) } }
    }
    private var deletedEvents: some View {
        NavigationStack {
            List {
                Text("Deleted events stay here until you restore them.").foregroundStyle(.secondary)
                let deleted = model.state.intervals.filter { $0.deletedAt != nil }.sorted { $0.start > $1.start }
                if deleted.isEmpty { Text("No deleted events.") }
                ForEach(deleted) { interval in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(eventName(interval)).font(.headline)
                        Text(interval.start, format: .dateTime.month().day().year().hour().minute()).font(.caption)
                        Button("Restore") {
                            Task { _ = await model.perform { try await model.store.restoreInterval(interval.id) } }
                        }.disabled(model.busy).accessibilityIdentifier("restore-\(eventName(interval))")
                    }.padding(.vertical, 4)
                }
            }.navigationTitle("Recently deleted")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showDeleted = false } } }
        }
    }
}
