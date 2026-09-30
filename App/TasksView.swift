import SwiftUI

struct TasksView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var audit = false
    @State private var management = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("What’s next?").font(.largeTitle.weight(.bold))
                            .padding(.top, 16).padding(.bottom, 24)
                            .accessibilityAddTraits(.isHeader)
                        if model.state.visibleTasks.isEmpty {
                            VStack(alignment: .leading, spacing: 20) {
                                Text("Add a task, then tap it to record.")
                                    .foregroundStyle(.secondary)
                                Button("Add task", systemImage: "plus") { management = true }
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
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 24)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .foregroundStyle(Theme.text)
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    undoBar
                    bottomLayout {
                        Button("Today", systemImage: "calendar") { audit = true }
                            .frame(minHeight: 44)
                        if !textSize.isAccessibilitySize { Spacer() }
                        Button("Manage tasks", systemImage: "list.bullet") { management = true }
                            .frame(minHeight: 44)
                    }.font(.subheadline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.horizontal, 24).padding(.vertical, 8)
                }.background(Theme.background.ignoresSafeArea(edges: .bottom))
            }
            .sheet(isPresented: $audit) { AuditView() }
            .sheet(isPresented: $management) { ManageTasksView() }
            .onOpenURL { url in
                if url.scheme == "frictionless" { audit = false; management = false }
            }
        }.background(Theme.background.ignoresSafeArea())
    }

    private var bottomLayout: AnyLayout {
        if textSize.isAccessibilitySize {
            return AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
        }
        return AnyLayout(HStackLayout())
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
