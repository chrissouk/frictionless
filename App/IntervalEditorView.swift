import SwiftUI

struct IntervalEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let interval: RecordedInterval
    @State private var taskID: UUID
    @State private var start: Date
    @State private var end: Date
    @State private var finish = false
    @State private var validation: String?

    init(interval: RecordedInterval) {
        self.interval = interval
        _taskID = State(initialValue: interval.taskID)
        _start = State(initialValue: interval.start)
        _end = State(initialValue: interval.end ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Task", selection: $taskID) {
                    ForEach(model.state.tasks.filter { !$0.archived || $0.id == interval.taskID }) { task in
                        Text(task.name).tag(task.id)
                    }
                }
                DatePicker("Started", selection: $start, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                if interval.end == nil { Toggle("Finish this recording", isOn: $finish) }
                if interval.end != nil || finish {
                    DatePicker("Ended", selection: $end, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
                }
                Section {
                    if interval.untrackedAt == nil {
                        Button("Mark as untracked", systemImage: "circle.dashed") {
                            Task {
                                if await model.perform({ try await model.store.markUntracked(interval.id) }) { dismiss() }
                            }
                        }.disabled(model.busy)
                    } else {
                        Text("Choose a task and save to track this time again.").foregroundStyle(.secondary)
                    }
                    Button("Delete event", systemImage: "trash", role: .destructive) {
                        Task {
                            if await model.perform({ try await model.store.removeInterval(interval.id) }) { dismiss() }
                        }
                    }.disabled(model.busy)
                    Text("Deleted events can be restored from Recently deleted.").font(.caption).foregroundStyle(.secondary)
                }
                if let validation { Text(validation).foregroundStyle(.red) }
            }.scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle("Correct interval").navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(model.busy) }
                }
        }
    }

    private var previousInterval: RecordedInterval? {
        model.state.intervals.first { $0.end == interval.start && $0.id != interval.id && $0.deletedAt == nil }
    }

    private func save() async {
        var savedEnd: Date?
        if interval.end != nil || finish { savedEnd = end }
        do {
            let result = try await model.store.correct(id: interval.id, taskID: taskID, start: start, end: savedEnd, previousID: previousInterval?.id)
            model.state = result
            await LiveCoordinator.shared.reconcile()
            dismiss()
        } catch { validation = error.localizedDescription }
    }

}
