import SwiftUI

struct ManageTasksView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var add = false
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
                                if task.shortcut {
                                    Image(systemName: "bolt.fill").foregroundStyle(Theme.mint)
                                        .accessibilityLabel("Live Activity shortcut")
                                }
                            }.frame(minHeight: 44)
                        }.listRowBackground(Theme.surface)
                    }.onMove { source, destination in
                        var ids = model.state.visibleTasks.map(\.id)
                        ids.move(fromOffsets: source, toOffset: destination)
                        Task { _ = await model.perform { try await model.store.reorder(ids) } }
                    }
                } footer: { Text("Drag to set a stable order. Tap a task to rename, choose its color, archive, or set a Live Activity shortcut (up to three).") }
                Button("Add task", systemImage: "plus") { add = true }.frame(minHeight: 44)
            }.scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle("Manage tasks")
                .environment(\.editMode, .constant(.active))
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(isPresented: $add) { TaskEditorView() }
                .sheet(item: $editing) { TaskEditorView(task: $0) }
        }
    }
}

struct TaskEditorView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var task: TrackedTask?
    @State private var name = ""
    @State private var color = 0
    @State private var shortcut = false
    @State private var loaded = false
    @State private var validation: String?
    var body: some View {
        NavigationStack {
            Form {
                TextField("Task name", text: $name).accessibilityIdentifier("task-name")
                if let validation { Text(validation).foregroundStyle(.red) }
                if task != nil {
                    Picker("Color", selection: $color) {
                        ForEach(0..<6) { index in
                            Text(colorNames[index]).tag(index)
                        }
                    }
                    Toggle("Live Activity shortcut", isOn: $shortcut)
                    Button("Archive task", role: .destructive) {
                        guard let task else { return }
                        Task {
                            if await model.perform({ try await model.store.archive(task.id) }) { dismiss() }
                        }
                    }
                    Text("Archiving keeps history and stops this task if it is recording.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }.scrollContentBackground(.hidden).background(Theme.background)
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task {
                                let saved = await model.perform {
                                    if let task { return try await model.store.saveTask(id: task.id, name: name, color: color, shortcut: shortcut) }
                                    return try await model.store.saveTask(name: name)
                                }
                                if saved { dismiss() }
                                else { validation = model.error; model.error = nil }
                            }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.busy)
                    }
                }.onAppear {
                    guard !loaded else { return }
                    loaded = true
                    if let task { name = task.name; color = task.color; shortcut = task.shortcut }
                }
        }
    }
    private var title: String {
        if task != nil { return "Edit task" }
        return "Add task"
    }
    private let colorNames = ["Mint", "Slate", "Sand", "Lavender", "Sage", "Rose"]
}
