import SwiftUI

@main
struct FrictionlessApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var phase
    var body: some Scene {
        WindowGroup {
            content.environmentObject(model)
                .tint(Theme.mint).preferredColorScheme(.dark)
                .task(id: phase) {
                    guard phase == .active else { return }
                    await model.reload()
                    while !Task.isCancelled {
                        do { try await Task.sleep(for: .seconds(60)) }
                        catch { return }
                        await model.reload()
                    }
                }
                .alert("Change could not be saved", isPresented: Binding(
                    get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
                    Button("OK") { model.error = nil }
                } message: { Text(model.error ?? "") }
        }
    }

    @ViewBuilder private var content: some View {
        if !model.loaded {
            ZStack { Theme.background.ignoresSafeArea(); ProgressView() }
        } else if model.onboarding != .complete {
            OnboardingView()
        } else {
            TasksView()
        }
    }
}
