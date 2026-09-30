import ActivityKit
import WidgetKit
import SwiftUI

@main
struct FrictionlessWidgets: WidgetBundle {
    var body: some Widget { RecordingWidget() }
}

struct RecordingWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingAttributes.self) { context in
            ActivityControls(state: context.state)
                .padding(16).activityBackgroundTint(Theme.background).activitySystemActionForegroundColor(Theme.mint)
                .widgetURL(URL(string: "frictionless://tasks"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.state.name, systemImage: "circle.fill")
                        .foregroundStyle(Theme.color(context.state.color)).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) { ActivityControls(state: context.state) }
            } compactLeading: {
                Image(systemName: "circle.fill").foregroundStyle(Theme.color(context.state.color))
                    .accessibilityLabel("Recording \(context.state.name)")
            } compactTrailing: {
                Text(context.state.name).font(.caption).lineLimit(1).frame(maxWidth: 70)
            } minimal: {
                Image(systemName: "circle.fill").foregroundStyle(Theme.color(context.state.color))
                    .accessibilityLabel("Recording \(context.state.name)")
            }.widgetURL(URL(string: "frictionless://tasks"))
                .keylineTint(Theme.mint)
        }
    }
}

struct ActivityControls: View {
    var state: RecordingAttributes.ContentState
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(state.name).font(.headline).lineLimit(2)
                Spacer()
                Text(state.start, style: .time).font(.caption).foregroundStyle(.secondary)
                    .accessibilityLabel("Started at \(state.start.formatted(date: .omitted, time: .shortened))")
            }
            HStack(spacing: 6) {
                ForEach(state.shortcuts) { shortcut in
                    Button(intent: SwitchTaskIntent(taskID: shortcut.id)) {
                        Text(shortcut.name).font(.caption).lineLimit(1).frame(maxWidth: .infinity, minHeight: 44)
                    }.buttonStyle(.bordered).tint(Theme.mint)
                        .accessibilityLabel("Record \(shortcut.name)")
                }
            }
            HStack {
                Link("All tasks", destination: URL(string: "frictionless://tasks")!).frame(minHeight: 44)
                Spacer()
                Button(intent: StopRecordingIntent()) {
                    Label("Stop", systemImage: "stop.circle").frame(minHeight: 44)
                }.buttonStyle(.plain)
            }.font(.subheadline).foregroundStyle(Theme.mint)
        }.foregroundStyle(Theme.text)
    }
}
