import SwiftUI

enum OnboardingStep: Int {
    case intro, tasks, current, reminder, complete
}

struct OnboardingView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    switch model.onboarding {
                    case .intro:
                        heading("A little less to think about.")
                        Text("Tap what you’re doing. Switch when it changes.")
                        Text("Later, Today shows where your time went. You can correct a missed switch there.")
                            .foregroundStyle(.secondary)
                    case .tasks:
                        heading("What fills your day?")
                        Text("Add the things you spend time on. You can change them later.")
                            .foregroundStyle(.secondary)
                        ForEach(model.state.visibleTasks) { task in
                            Label {
                                Text(task.name)
                            } icon: {
                                Circle().fill(Theme.color(task.color)).frame(width: 10, height: 10)
                            }.frame(minHeight: 44)
                        }
                        TaskCreator()
                    case .current:
                        heading("What are you doing right now?")
                        Text("Tap a task to start recording.").foregroundStyle(.secondary)
                        ForEach(model.state.visibleTasks) { task in
                            Button {
                                Task {
                                    if await model.perform({ try await model.store.switchTask(task.id) }) {
                                        model.setOnboarding(.reminder)
                                    }
                                }
                            } label: {
                                HStack {
                                    Circle().fill(Theme.color(task.color)).frame(width: 10, height: 10)
                                    Text(task.name).font(.title2)
                                    Spacer()
                                }.padding(.vertical, 16).contentShape(Rectangle())
                            }.buttonStyle(.plain).disabled(model.busy)
                                .accessibilityIdentifier("onboarding-task-\(task.name)")
                            Divider()
                        }
                    case .reminder:
                        heading("You’re recording.")
                        Text("Close the app or lock your phone. Recording keeps going until you switch or stop.")
                        Text("Use Switch! on your Lock Screen to jump back in.")
                            .foregroundStyle(.secondary)
                        Text("Your records are stored on this iPhone. Frictionless doesn’t upload or sync them.")
                            .foregroundStyle(.secondary)
                    case .complete:
                        EmptyView()
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(24)
            }
        }.foregroundStyle(Theme.text)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    switch model.onboarding {
                    case .intro:
                        nextButton("Get started", step: .tasks)
                    case .tasks:
                        nextButton("Continue", step: .current).disabled(model.state.visibleTasks.isEmpty || model.busy)
                    case .current:
                        Button("Edit tasks") { model.setOnboarding(.tasks) }.frame(minHeight: 44)
                    case .reminder:
                        nextButton("Let’s go", step: .complete)
                    case .complete:
                        EmptyView()
                    }
                }.padding(24).frame(maxWidth: .infinity)
                    .background(Theme.background.ignoresSafeArea(edges: .bottom))
            }
    }

    private func heading(_ text: String) -> some View {
        Text(text).font(.largeTitle.weight(.bold)).accessibilityAddTraits(.isHeader)
    }

    private func nextButton(_ title: String, step: OnboardingStep) -> some View {
        Button(title) { model.setOnboarding(step) }
            .buttonStyle(.borderedProminent).foregroundStyle(Theme.background).frame(minHeight: 44)
    }
}

struct TaskCreator: View {
    @EnvironmentObject private var model: AppModel
    @State private var name = ""
    @State private var validation: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(Theme.mint).accessibilityHidden(true)
                TextField("New task", text: $name).accessibilityIdentifier("new-task-name")
                    .focused($focused).submitLabel(.done)
                    .onSubmit { Task { await addTask() } }
                if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("Add") { Task { await addTask() } }
                        .buttonStyle(.borderless).frame(minHeight: 44).disabled(model.busy)
                }
            }.frame(minHeight: 44)
            if let validation { Text(validation).foregroundStyle(.red) }
        }.task { if model.state.visibleTasks.isEmpty { focused = true } }
    }

    private func addTask() async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !model.busy else { return }
        if await model.perform({ try await model.store.saveTask(name: trimmed) }) {
            name = ""; validation = nil; focused = true
        } else {
            validation = model.error; model.error = nil
        }
    }
}
