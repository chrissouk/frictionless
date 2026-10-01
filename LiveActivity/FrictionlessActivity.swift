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
                DynamicIslandExpandedRegion(.bottom) { ActivityControls(state: context.state) }
            } compactLeading: {
                Image(systemName: "circle.fill").foregroundStyle(Theme.color(context.state.color))
                    .accessibilityLabel("Recording \(context.state.name)")
            } compactTrailing: {
                Text(context.state.start, style: .timer).monospacedDigit().font(.caption2).frame(width: 72)
            } minimal: {
                Image(systemName: "circle.fill").foregroundStyle(Theme.color(context.state.color))
                    .accessibilityLabel("Recording \(context.state.name)")
            }.widgetURL(URL(string: "frictionless://tasks"))
                .keylineTint(Theme.color(context.state.color))
        }
    }
}

struct ActivityControls: View {
    var state: RecordingAttributes.ContentState
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.color(state.color)).frame(width: 12, height: 12)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(state.name).font(.headline).lineLimit(2)
                Text(state.start, style: .timer).font(.title3).monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }.frame(maxWidth: .infinity, alignment: .leading)
            Link("Switch!", destination: URL(string: "frictionless://tasks")!)
                .font(.subheadline.weight(.semibold)).fixedSize()
                .padding(.horizontal, 14).frame(minHeight: 44)
                .foregroundStyle(Theme.background)
                .background(Theme.color(state.color), in: Capsule())
        }.padding(12).foregroundStyle(Theme.text)
            .background(Theme.color(state.color).opacity(0.16), in: RoundedRectangle(cornerRadius: 16))
    }
}
