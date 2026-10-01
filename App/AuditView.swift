import SwiftUI

struct AuditView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var day = Date()
    @State private var editing: RecordedInterval?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: Date(), by: 30)) { context in
                let audit = DailyAudit.make(state: model.state, day: day, now: context.date)
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Button("Previous day", systemImage: "chevron.left") { shiftDay(-1) }
                                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                            Spacer()
                            Text(day, format: .dateTime.month(.abbreviated).day().year()).font(.headline)
                            Spacer()
                            Button("Next day", systemImage: "chevron.right") { shiftDay(1) }
                                .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                                .disabled(Calendar.current.isDateInToday(day))
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(durationLabel(audit.tracked)).font(.largeTitle.weight(.semibold))
                            Text("Total tracked time").foregroundStyle(.secondary)
                        }
                        DayClock(segments: audit.segments, tasks: model.state.tasks)
                        if audit.totals.isEmpty { Text("No recorded time for this day.").foregroundStyle(.secondary) }
                        ForEach(model.state.tasks.filter { audit.totals[$0.id] != nil }.sorted { $0.order < $1.order }) { task in
                            let total = audit.totals[task.id, default: 0]
                            VStack(alignment: .leading, spacing: 8) {
                                HStack { Text(task.name); Spacer(); Text(durationLabel(total)).foregroundStyle(.secondary) }
                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: 3).fill(Theme.color(task.color))
                                        .frame(width: max(3, geometry.size.width * total / max(audit.tracked, 1)))
                                }.frame(height: 8).accessibilityHidden(true)
                            }.accessibilityElement(children: .combine)
                        }
                        Text("Timeline").font(.title2.weight(.medium)).padding(.top, 8)
                        ForEach(audit.segments.reversed()) { segment in
                            if let interval = segment.interval {
                                let taskName = model.state.tasks.first { $0.id == interval.taskID }?.name ?? "Task"
                                Button { editing = interval } label: { segmentRow(segment) }
                                    .accessibilityIdentifier("interval-\(taskName)")
                                    .buttonStyle(.plain).accessibilityHint("Edit task or recording times")
                            } else { segmentRow(segment) }
                            Divider()
                        }
                    }.padding(24)
                }.background(Theme.background).foregroundStyle(Theme.text)
            }.navigationTitle("Daily audit").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .sheet(item: $editing) { IntervalEditorView(interval: $0) }
        }
    }

    private func shiftDay(_ value: Int) {
        if let next = Calendar.current.date(byAdding: .day, value: value, to: day) { day = next }
    }

    private func segmentRow(_ segment: AuditSegment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                if let interval = segment.interval, let task = model.state.tasks.first(where: { $0.id == interval.taskID }) {
                    Image(systemName: "circle.fill").font(.caption2).foregroundStyle(Theme.color(task.color))
                    Text(task.name).font(.headline)
                    if interval.end == nil { Text("Recording").font(.caption).foregroundStyle(Theme.mint) }
                } else {
                    Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                    Text("Untracked").foregroundStyle(.secondary)
                }
                Spacer()
                Text(durationLabel(segment.duration)).font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text(segment.start, format: .dateTime.hour().minute())
                Text("–")
                Text(segment.end, format: .dateTime.hour().minute())
            }.font(.caption).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity, minHeight: 60, alignment: .leading).contentShape(Rectangle())
    }
}

private struct DayClock: View {
    let segments: [AuditSegment]
    let tasks: [TrackedTask]

    var body: some View {
        Canvas { context, size in
            drawClock(context: &context, size: size)
        }.frame(maxWidth: 280).aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("day-clock")
            .accessibilityLabel("24-hour clock. Midnight at the top, 6 AM at the right, noon at the bottom, 6 PM at the left. Colored arcs show tracked time; dark arcs are untracked.")
    }

    private func drawClock(context: inout GraphicsContext, size: CGSize) {
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 34
            let ringWidth: CGFloat = 28
            let outer = CGRect(x: center.x - radius, y: center.y - radius,
                               width: radius * 2, height: radius * 2)
            context.stroke(Path(ellipseIn: outer), with: .color(Theme.surface), lineWidth: ringWidth)

            for segment in segments {
                guard let interval = segment.interval,
                      let task = tasks.first(where: { $0.id == interval.taskID }) else { continue }
                var minute = segment.start
                var arc = Path()
                while minute < segment.end {
                    let boundary = Calendar.current.dateInterval(of: .minute, for: minute)!.end
                    let end = min(boundary, segment.end)
                    let parts = Calendar.current.dateComponents([.hour, .minute, .second], from: minute)
                    let startMinute = Double(parts.hour! * 60 + parts.minute!) + Double(parts.second!) / 60
                    let endMinute = startMinute + end.timeIntervalSince(minute) / 60
                    let angle: Double = (startMinute / 4 - 90) * Double.pi / 180
                    let cosine = CGFloat(Foundation.cos(angle))
                    let sine = CGFloat(Foundation.sin(angle))
                    arc.move(to: CGPoint(x: center.x + cosine * (radius + ringWidth / 2),
                                         y: center.y + sine * (radius + ringWidth / 2)))
                    arc.addArc(center: center, radius: radius + ringWidth / 2,
                               startAngle: .degrees(startMinute / 4 - 90),
                               endAngle: .degrees(endMinute / 4 - 90), clockwise: false)
                    arc.addArc(center: center, radius: radius - ringWidth / 2,
                               startAngle: .degrees(endMinute / 4 - 90),
                               endAngle: .degrees(startMinute / 4 - 90), clockwise: true)
                    arc.closeSubpath()
                    minute = end
                }
                context.fill(arc, with: .color(Theme.color(task.color)))
            }

            for edge in [radius - ringWidth / 2, radius + ringWidth / 2] {
                let border = CGRect(x: center.x - edge, y: center.y - edge, width: edge * 2, height: edge * 2)
                context.stroke(Path(ellipseIn: border), with: .color(Theme.text.opacity(0.35)), lineWidth: 1)
            }
            for hour in 0..<24 {
                let angle = Double(hour) * .pi / 12 - .pi / 2
                let cosine = CGFloat(Foundation.cos(angle))
                let sine = CGFloat(Foundation.sin(angle))
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cosine * (radius + 17),
                                     y: center.y + sine * (radius + 17)))
                tick.addLine(to: CGPoint(x: center.x + cosine * (radius + 21),
                                        y: center.y + sine * (radius + 21)))
                context.stroke(tick, with: .color(Theme.text.opacity(0.5)), lineWidth: 1)
            }
            context.draw(Text("00").font(.system(size: 12)).foregroundStyle(.secondary), at: CGPoint(x: center.x, y: 8))
            context.draw(Text("06").font(.system(size: 12)).foregroundStyle(.secondary), at: CGPoint(x: size.width - 10, y: center.y))
            context.draw(Text("12").font(.system(size: 12)).foregroundStyle(.secondary), at: CGPoint(x: center.x, y: size.height - 8))
            context.draw(Text("18").font(.system(size: 12)).foregroundStyle(.secondary), at: CGPoint(x: 10, y: center.y))
    }
}
