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
                Section("Started earlier") {
                    HStack {
                        ForEach([5, 15, 30], id: \.self) { minutes in
                            Button("\(minutes)m") { start = interval.start.addingTimeInterval(Double(-minutes * 60)) }
                                .frame(maxWidth: .infinity, minHeight: 44).buttonStyle(.borderless)
                        }
                    }
                    if previousInterval != nil {
                        Text("Changing this start also adjusts the previous task’s end.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if interval.end == nil { Toggle("Finish this recording", isOn: $finish) }
                if interval.end != nil || finish {
                    DatePicker("Ended", selection: $end, in: ...Date(), displayedComponents: [.date, .hourAndMinute])
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
        model.state.intervals.first { $0.end == interval.start && $0.id != interval.id }
    }

    private func save() async {
        var savedEnd: Date?
        if interval.end != nil || finish { savedEnd = end }
        do {
            let result = try await model.store.correct(id: interval.id, taskID: taskID, start: start, end: savedEnd, previousID: previousInterval?.id)
            model.state = result
            model.presentationNotice = await LiveCoordinator.shared.reconcile()
            dismiss()
        } catch { validation = error.localizedDescription }
    }

}
