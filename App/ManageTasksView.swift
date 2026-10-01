import SwiftUI

struct ManageTasksView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var newTaskName = ""
    @State private var validation: String?
    @FocusState private var creatorFocused: Bool
    @State private var editing: TrackedTask?
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(model.state.visibleTasks) { task in
                        Button { editing = task } label: {
                            HStack {
                                Circle().fill(Theme.color(task.color)).frame(width: 10, height: 10)
                                Text(task.name).foregroundStyle(Theme.text)
                                Spacer()
                            }.frame(minHeight: 44)
                        }.listRowBackground(Theme.surface)
                            .accessibilityIdentifier("managed-task-\(task.name)")
                    }.onMove { source, destination in
                        var ids = model.state.visibleTasks.map(\.id)
                        ids.move(fromOffsets: source, toOffset: destination)
                        Task { _ = await model.perform { try await model.store.reorder(ids) } }
                    }
                } footer: { Text("Drag to reorder. Tap a task to edit it.") }
                HStack {
                    Image(systemName: "plus.circle.fill").foregroundStyle(Theme.mint)
                        .accessibilityHidden(true)
                    TextField("New task", text: $newTaskName)
                        .accessibilityIdentifier("new-task-name")
                        .focused($creatorFocused).submitLabel(.done)
                        .onSubmit { Task { await addTask() } }
                    if !newTaskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Add") { Task { await addTask() } }
                            .buttonStyle(.borderless).frame(minHeight: 44).disabled(model.busy)
                    }
                }.frame(minHeight: 44).listRowBackground(Theme.surface)
                if let validation { Text(validation).foregroundStyle(.red) }
            }.scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle("Manage tasks")
                .environment(\.editMode, .constant(.active))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $editing) { TaskEditorView(task: $0) }
                .task {
                    if model.state.visibleTasks.isEmpty { creatorFocused = true }
                }
        }
    }

    private func addTask() async {
        let name = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !model.busy else { return }
        if await model.perform({ try await model.store.saveTask(name: name) }) {
            newTaskName = ""
            validation = nil
            creatorFocused = true
        } else {
            validation = model.error
            model.error = nil
        }
    }
}

struct TaskEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    let task: TrackedTask
    @State private var name = ""
    @State private var color = 0
    @State private var loaded = false
    @State private var validation: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Task name", text: $name).accessibilityIdentifier("task-name")
                if let validation { Text(validation).foregroundStyle(.red) }
                Picker("Color", selection: $color) {
                    ForEach(0..<6) { index in
                        Label {
                            Text(colorNames[index])
                        } icon: {
                            Circle().fill(Theme.color(index)).frame(width: 16, height: 16)
                        }.tag(index)
                    }
                }.pickerStyle(.navigationLink).accessibilityIdentifier("task-color")
                Button("Archive task", role: .destructive) {
                    Task {
                        if await model.perform({ try await model.store.archive(task.id) }) { dismiss() }
                    }
                }
                Text("Archiving keeps history and stops this task if it is recording.")
                    .font(.footnote).foregroundStyle(.secondary)
            }.scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle("Edit task")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                let saved = await model.perform {
                                    try await model.store.saveTask(id: task.id, name: name, color: color)
                                }
                                if saved { dismiss() }
                                else { validation = model.error; model.error = nil }
                            }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.busy)
                    }
                }.onAppear {
                    guard !loaded else { return }
                    loaded = true
                    name = task.name; color = task.color
                }
        }
    }
    private let colorNames = ["Mint", "Slate", "Sand", "Lavender", "Sage", "Rose"]
}
