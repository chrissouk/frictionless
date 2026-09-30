import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var state = RecordingState()
    @Published var error: String?
    @Published var presentationNotice: String?
    @Published var busy = false
    private var pendingOperations = 0
    let store = RecordingStore.shared

    func reload() async {
        do {
            var latest = try await store.snapshot()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--audit-fixture"), latest.tasks.isEmpty,
               ProcessInfo.processInfo.arguments.contains("--ui-testing") {
                latest = try await store.saveTask(name: "Writing")
                latest = try await store.saveTask(name: "Reading")
                let tasks = latest.visibleTasks
                let today = Calendar.current.startOfDay(for: Date())
                _ = try await store.switchTask(tasks[0].id, now: today.addingTimeInterval(3600))
                _ = try await store.switchTask(tasks[1].id, now: today.addingTimeInterval(7200))
                latest = try await store.switchTask(nil, now: today.addingTimeInterval(10800))
            }
            #endif
            if latest.revision >= state.revision { state = latest }
        }
        catch { self.error = error.localizedDescription }
        presentationNotice = await LiveCoordinator.shared.reconcile()
    }

    func perform(_ operation: () async throws -> RecordingState) async -> Bool {
        pendingOperations += 1
        busy = true
        defer {
            pendingOperations -= 1
            busy = pendingOperations > 0
        }
        do {
            let latest = try await operation()
            if latest.revision >= state.revision { state = latest }
            presentationNotice = await LiveCoordinator.shared.reconcile()
            return true
        } catch { self.error = error.localizedDescription; return false }
    }

    func select(_ id: UUID?) async {
        let previousRevision = state.revision
        if await perform({ try await store.switchTask(id) }), state.revision != previousRevision {
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}
