import SwiftUI

struct DayClock: View {
    let segments: [AuditSegment]
    let tasks: [TrackedTask]
    var showsTotal = true

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
            let radius = min(size.width, size.height) * 0.32
            let ringWidth: CGFloat = min(size.width, size.height) * 0.09
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
                context.stroke(Path(ellipseIn: border), with: .color(Theme.text.opacity(0.12)), lineWidth: 1)
            }
            for hour in 0..<24 {
                let angle = Double(hour) * .pi / 12 - .pi / 2
                let cosine = CGFloat(Foundation.cos(angle))
                let sine = CGFloat(Foundation.sin(angle))
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + cosine * (radius + ringWidth / 2 + 4),
                                     y: center.y + sine * (radius + ringWidth / 2 + 4)))
                tick.addLine(to: CGPoint(x: center.x + cosine * (radius + ringWidth / 2 + 8),
                                        y: center.y + sine * (radius + ringWidth / 2 + 8)))
                context.stroke(tick, with: .color(Theme.text.opacity(0.5)), lineWidth: 1)
            }
            let labelRadius = min(size.width, size.height) * 0.46
            for (hour, label) in [(0, "00"), (6, "06"), (12, "12"), (18, "18")] {
                let angle = Double(hour) * .pi / 12 - .pi / 2
                let point = CGPoint(x: center.x + CGFloat(cos(angle)) * labelRadius,
                                    y: center.y + CGFloat(sin(angle)) * labelRadius)
                context.draw(Text(label).font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.text.opacity(0.6)), at: point)
            }
            if showsTotal {
                let tracked = segments.filter { $0.interval != nil }.reduce(0) { $0 + $1.duration }
                context.draw(Text(durationLabel(tracked)).font(.system(size: min(size.width, size.height) * 0.08,
                    weight: .semibold, design: .rounded)).foregroundStyle(Theme.text), at: center)
                context.draw(Text("TRACKED").font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.text.opacity(0.5)), at: CGPoint(x: center.x, y: center.y + 21))
            }
    }
}
