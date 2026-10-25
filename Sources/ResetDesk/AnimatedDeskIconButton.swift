import SwiftUI

/// One finite hover gesture. Clicking never waits for the animation to finish.
struct AnimatedDeskIconButton: View {
    let kind: DeskMotionIcon
    let title: String
    var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var enabled
    @State private var hovering = false
    @State private var pulse = 0

    var body: some View {
        let motionAllowed = !reduceMotion && enabled
        let icon = kind
        return Button(action: action) {
            Color.clear.frame(width: 16, height: 16)
                .keyframeAnimator(initialValue: DeskIconMotionFrame(), trigger: pulse) { _, frame in
                    DeskMotionGlyph(kind: icon, frame: motionAllowed ? frame : DeskIconMotionFrame())
                } keyframes: { _ in
                    KeyframeTrack(\.rotation) {
                        CubicKeyframe(90, duration: 0.32)
                        CubicKeyframe(0, duration: 0.40)
                    }
                    KeyframeTrack(\.slide) {
                        CubicKeyframe(1, duration: 0.24)
                        CubicKeyframe(-0.4, duration: 0.24)
                        CubicKeyframe(0, duration: 0.24)
                    }
                }
                .accessibilityHidden(true)
        }.buttonStyle(DeskIconButton())
            .onHover { inside in
                if inside, !hovering, enabled, !reduceMotion { pulse &+= 1 }
                hovering = inside
            }
            .help(title).accessibilityLabel(title)
    }
}

enum DeskMotionIcon: Sendable { case gear, preferences }

struct DeskIconMotionFrame: Sendable {
    var rotation: Double = 0
    var slide: Double = 0
}

struct DeskMotionGlyph: View {
    let kind: DeskMotionIcon
    var frame = DeskIconMotionFrame()
    var body: some View {
        Group {
            if kind == .gear {
                Image(systemName: "gearshape").font(.system(size: 14))
                    .rotationEffect(.degrees(frame.rotation))
            } else {
                PreferencesSliders(travel: frame.slide)
                    .stroke(style: StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round))
            }
        }.frame(width: 16, height: 16)
    }
}

/// Separate knob paths let each slider move without rotating or distorting the
/// recognizable three-line Preferences symbol. No opaque fill: both themes work.
private struct PreferencesSliders: Shape {
    var travel: Double
    var animatableData: Double {
        get { travel }
        set { travel = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let centers: [CGFloat] = [4.5, 10.5, 6.5]
        let distances: [CGFloat] = [3, -3, 2.5]
        let scaleX = rect.width / 16
        let scaleY = rect.height / 16
        for index in 0..<3 {
            let x = (centers[index] + distances[index] * CGFloat(travel)) * scaleX + rect.minX
            let y = CGFloat(3 + index * 5) * scaleY + rect.minY
            let halfWidth = 1.5 * scaleX
            path.move(to: CGPoint(x: rect.minX + scaleX, y: y))
            path.addLine(to: CGPoint(x: x - halfWidth, y: y))
            path.addRoundedRect(in: CGRect(x: x - halfWidth, y: y - 1.9 * scaleY,
                                           width: 3 * scaleX, height: 3.8 * scaleY),
                                cornerSize: CGSize(width: 0.7 * scaleX, height: 0.7 * scaleY))
            path.move(to: CGPoint(x: x + halfWidth, y: y))
            path.addLine(to: CGPoint(x: rect.maxX - scaleX, y: y))
        }
        return path
    }
}
