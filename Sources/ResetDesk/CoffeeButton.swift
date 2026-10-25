import SwiftUI
import AppKit

/// Review alternatives share one glyph and one real toggle implementation.
/// The normal dashboard uses Pour; comparison controls live only in scripts/.
enum CoffeeAnimation: String, CaseIterable { case brew, steam, pour }

struct CoffeeButton: View {
    @ObservedObject var controller: KeepAwakeController
    var variant: CoffeeAnimation = .pour
    // Review may request less motion, but never override the macOS preference.
    var reduceMotionOverride = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var progress: Double = 0
    @State private var visible = false
    @State private var loopStart = Date()

    private var motionReduced: Bool { reduceMotion || reduceMotionOverride }
    private var shouldLoop: Bool { controller.isEnabled && visible && !motionReduced }

    var body: some View {
        Button { controller.toggle() } label: {
            Group {
                if shouldLoop {
                    // This subtree, including its clock, is removed while hidden,
                    // Off or reduced. Animation never acquires a sleep assertion.
                    TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
                        CoffeeGlyph(variant: variant, active: true,
                                    loop: CoffeeLoopFrame(elapsed: context.date.timeIntervalSince(loopStart)))
                    }
                } else {
                    CoffeeGlyph(variant: variant, progress: motionReduced || controller.isEnabled ? 0 : progress,
                                active: controller.isEnabled)
                }
            }.frame(width: 20, height: 20).accessibilityHidden(true)
        }.buttonStyle(DeskIconButton())
            .onHover { inside in
                guard inside != hovering else { return }
                hovering = inside
                if inside && !motionReduced && !controller.isEnabled {
                    withAnimation(.linear(duration: variant == .steam ? 0.75 : 0.85)) { progress = 1 }
                } else { reset() }
            }
            .onChange(of: motionReduced) { _, _ in reset() }
            .onChange(of: controller.isEnabled) { _, _ in reset() }
            .onChange(of: shouldLoop) { _, running in if running { loopStart = .now } }
            .background(CoffeeVisibilityReader { visible = $0 })
            .onDisappear { visible = false; reset() }
            .help(controller.isEnabled
                  ? "Keep awake: On. Click to turn off. Prevents idle system sleep until quit. Display may sleep; lid-close and forced sleep still apply."
                  : "Keep awake: Off. Click to prevent idle system sleep until quit. Display may sleep; lid-close and forced sleep still apply.")
            .accessibilityLabel("Keep awake")
            .accessibilityValue(controller.isEnabled ? "On" : "Off")
            .accessibilityAddTraits(controller.isEnabled ? .isSelected : [])
            .accessibilityHint("Prevents idle system sleep. Display sleep is unchanged. Click to toggle.")
            .alert("Keep awake", isPresented: Binding(get: { controller.error != nil }, set: { if !$0 { controller.dismissError() } })) {
                Button("OK") { controller.dismissError() }
            } message: { Text(controller.error ?? "") }
    }
    private func reset() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) { progress = 0 }
    }
}

/// A closed periodic curve gives the liquid/steam identical position and
/// velocity at each seam. This frame is visual only, independent of power state.
struct CoffeeLoopFrame {
    static let period: TimeInterval = 2.4
    let wave: Double
    let steamSway: Double
    let steamLift: Double
    let steamOpacity: Double
    init(elapsed: TimeInterval) {
        let angle = 2 * Double.pi * max(0, elapsed) / Self.period
        wave = 1.3 * sin(angle)
        steamSway = 0.45 * sin(angle)
        steamLift = 0.45 * (1 - cos(angle))
        steamOpacity = 0.78 + 0.12 * cos(angle)
    }
}

/// Original vectors, normalized to 20 points. The inactive reveal is finite;
/// the active loop changes liquid and steam only, keeping the cup recognizable.
struct CoffeeGlyph: View, Animatable {
    var variant: CoffeeAnimation = .pour
    var progress: Double = 0
    var active = false
    var loop: CoffeeLoopFrame?
    @Environment(\.colorScheme) private var colorScheme
    var animatableData: Double { get { progress } set { progress = newValue } }

    var body: some View {
        let p = min(1, max(0, progress))
        let eased = 1 - pow(1 - p, 3)
        let reveal = active || variant == .brew || p == 0 ? 1 : eased
        let fill = active ? 0.66 : (variant == .steam ? 0 : 0.63 * eased)
        let wave = loop?.wave ?? (variant == .steam ? 0 : sin(p * .pi * 3) * sin(p * .pi) * (variant == .pour ? 1.5 : 1.0))
        let coffee = colorScheme == .dark ? Color(red: 0.76, green: 0.52, blue: 0.31) : Color(red: 0.48, green: 0.27, blue: 0.12)
        Canvas { context, size in
            context.scaleBy(x: size.width / 20, y: size.height / 20)
            let ink = Color.primary.opacity(active ? 0.94 : 0.74)
            let stroke = StrokeStyle(lineWidth: 1.05, lineCap: .round, lineJoin: .round)
            var cup = Path()
            cup.move(to: CGPoint(x: 3.4, y: 7.2))
            cup.addLine(to: CGPoint(x: 3.8, y: 12.6))
            cup.addCurve(to: CGPoint(x: 8.7, y: 16), control1: CGPoint(x: 4, y: 15.2), control2: CGPoint(x: 6, y: 16))
            cup.addCurve(to: CGPoint(x: 13.6, y: 12.6), control1: CGPoint(x: 11.5, y: 16), control2: CGPoint(x: 13.4, y: 15.2))
            cup.addLine(to: CGPoint(x: 14, y: 7.2)); cup.closeSubpath()
            var liquid = Path()
            let y = 15.7 - 8.3 * fill
            liquid.move(to: CGPoint(x: 2.5, y: y))
            liquid.addCurve(to: CGPoint(x: 15, y: y), control1: CGPoint(x: 6, y: y + wave * 1.3), control2: CGPoint(x: 10, y: y - wave * 1.3))
            liquid.addLine(to: CGPoint(x: 15, y: 17)); liquid.addLine(to: CGPoint(x: 2.5, y: 17)); liquid.closeSubpath()
            if fill > 0 {
                var clipped = context; clipped.clip(to: cup)
                clipped.fill(liquid, with: .color(coffee))
            }
            if variant != .brew { context.stroke(cup, with: .color(ink.opacity(0.22)), style: stroke) }
            context.stroke(cup.trimmedPath(from: 0, to: reveal), with: .color(ink), style: stroke)
            var rim = Path(); rim.move(to: CGPoint(x: 3.4, y: 7.2)); rim.addLine(to: CGPoint(x: 14, y: 7.2))
            context.stroke(rim, with: .color(ink), style: stroke)
            var handle = Path(); handle.move(to: CGPoint(x: 14, y: 8))
            handle.addCurve(to: CGPoint(x: 14, y: 12.9), control1: CGPoint(x: 18.8, y: 6.9), control2: CGPoint(x: 18.4, y: 13))
            if variant != .brew { context.stroke(handle, with: .color(ink.opacity(0.22)), style: stroke) }
            context.stroke(handle.trimmedPath(from: 0, to: reveal), with: .color(ink), style: stroke)
            var saucer = Path(); saucer.move(to: CGPoint(x: 2.6, y: 17.8)); saucer.addQuadCurve(to: CGPoint(x: 15, y: 17.8), control: CGPoint(x: 8.8, y: 18.5))
            context.stroke(saucer, with: .color(ink), style: stroke)
            let steam = active ? 1 : variant == .brew ? eased * 0.65 : eased
            let steamOpacity = loop?.steamOpacity ?? steam
            for x in [7.0, 10.5] {
                let sway = loop?.steamSway ?? 0
                let lift = loop?.steamLift ?? 0
                var path = Path(); path.move(to: CGPoint(x: x, y: 5.6 - lift * 0.3))
                path.addCurve(to: CGPoint(x: x + sway, y: 1.7 - lift), control1: CGPoint(x: x - 1.8 + sway, y: 4.1 - lift), control2: CGPoint(x: x + 1.8 + sway, y: 3.4 - lift))
                context.stroke(path.trimmedPath(from: 0, to: steam), with: .color(ink.opacity(steamOpacity)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
            if active {
                // Shape + filled coffee identify On without relying on hue.
                let dot = Path(ellipseIn: CGRect(x: 16.2, y: 15.6, width: 2.4, height: 2.4))
                context.fill(dot, with: .color(ink))
            }
        }
    }
}

/// Cached popovers retain SwiftUI views while ordered out. Observe the owning
/// window instead of assuming onDisappear always fires. Occlusion also suspends
/// work for minimized/fully covered review windows. No polling timer is needed.
struct CoffeeVisibilityReader: NSViewRepresentable {
    var update: (Bool) -> Void
    func makeNSView(context: Context) -> VisibilityView { VisibilityView(update: update) }
    func updateNSView(_ nsView: VisibilityView, context: Context) { nsView.update = update }

    final class VisibilityView: NSView {
        var update: (Bool) -> Void
        private var observation: NSObjectProtocol?
        private var lastValue: Bool?
        init(update: @escaping (Bool) -> Void) { self.update = update; super.init(frame: .zero) }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let observation { NotificationCenter.default.removeObserver(observation) }
            observation = nil
            if let window {
                observation = NotificationCenter.default.addObserver(forName: NSWindow.didChangeOcclusionStateNotification,
                                                                     object: window, queue: .main) { [weak self] _ in self?.refresh() }
            }
            refresh()
        }
        private func refresh() {
            let value = window?.isVisible == true && window?.occlusionState.contains(.visible) == true && !isHiddenOrHasHiddenAncestor
            guard value != lastValue else { return }
            lastValue = value
            // Window attachment can happen inside a SwiftUI update transaction.
            DispatchQueue.main.async { [weak self] in self?.update(value) }
        }
        deinit { if let observation { NotificationCenter.default.removeObserver(observation) } }
    }
}
