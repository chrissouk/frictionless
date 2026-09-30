import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var audit = false
    @State private var management = false
    @State private var creation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if model.state.visibleTasks.isEmpty {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Make room for your day.").font(.title2.weight(.medium))
                            Text("Add the things you spend time on. Tap one to start recording.")
                                .foregroundStyle(.secondary)
                            Button("Add task", systemImage: "plus") { creation = true }
                                .buttonStyle(.borderedProminent).foregroundStyle(Theme.background)
                                .frame(minHeight: 44)
                        }.padding(.vertical, 48)
                    }
                    ForEach(model.state.visibleTasks) { task in
                        taskRow(task)
                        Divider()
                    }
                    if model.state.active != nil {
                        Button("Stop tracking", systemImage: "stop.circle") {
                            Task { await model.select(nil) }
                        }.frame(minHeight: 56).padding(.top, 20)
                    }
                    if let notice = model.presentationNotice {
                        Text(notice).font(.footnote).foregroundStyle(.secondary).padding(.top, 16)
                    }
                }.padding(.horizontal, 24)
            }
            .background(Theme.background).foregroundStyle(Theme.text)
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Today") { audit = true }.frame(minHeight: 44)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Manage tasks", systemImage: "slider.horizontal.3") { management = true }
                        .frame(minWidth: 44, minHeight: 44)
                }
            }
            .safeAreaInset(edge: .bottom) { undoBar }
            .sheet(isPresented: $audit) { AuditView() }
            .sheet(isPresented: $management) { ManageTasksView() }
            .sheet(isPresented: $creation) { TaskEditorView() }
            .onOpenURL { url in
                if url.scheme == "frictionless" { audit = false; management = false; creation = false }
            }
        }
    }

    private func taskRow(_ task: TrackedTask) -> some View {
        let selected = model.state.active?.taskID == task.id
        return Button {
            Task { await model.select(task.id) }
        } label: {
            HStack(spacing: 16) {
                Circle().fill(Theme.color(task.color)).frame(width: 10, height: 10)
                Text(task.name).font(.title2.weight(.medium)).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.mint) }
            }.padding(.vertical, 25).frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                .contentShape(Rectangle())
        }.buttonStyle(.plain)
            .accessibilityIdentifier("task-\(task.name)")
            .accessibilityValue(selectedDescription(selected))
    }

    private func selectedDescription(_ selected: Bool) -> String {
        if selected { return "Recording" }
        return "Tap to record"
    }

    @ViewBuilder private var undoBar: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            if let undo = model.state.undo, undo.revision == model.state.revision, context.date <= undo.expires {
                HStack {
                    Text("Saved").foregroundStyle(.secondary)
                    Spacer()
                    Button("Undo") {
                        Task { _ = await model.perform { try await model.store.undo(undo.token) } }
                    }.frame(minHeight: 44)
                }.padding(.horizontal, 24).background(Theme.surface)
            }
        }
    }
}
