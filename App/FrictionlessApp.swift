import SwiftUI

@main
struct FrictionlessApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            TasksView().environmentObject(model)
                .tint(Theme.mint).preferredColorScheme(.dark)
                .task { await model.reload() }
                .onChange(of: phase) { _, value in
                    if value == .active { Task { await model.reload() } }
                }
                .alert("Change could not be saved", isPresented: Binding(
                    get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK") { model.error = nil }
                } message: { Text(model.error ?? "") }
        }
    }
}
