import SwiftUI

/// Review alternatives share one glyph and one real toggle implementation.
/// The normal dashboard uses Brew; comparison controls live only in scripts/.
enum CoffeeAnimation: String, CaseIterable { case brew, steam, pour }

struct CoffeeButton: View {
    @ObservedObject var controller: KeepAwakeController
    var variant: CoffeeAnimation = .brew
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @State private var progress: Double = 0

    var body: some View {
        Button { controller.toggle() } label: {
            CoffeeGlyph(variant: variant, progress: reduceMotion ? 0 : progress, active: controller.isEnabled)
                .frame(width: 20, height: 20).accessibilityHidden(true)
        }.buttonStyle(DeskIconButton())
            .onHover { inside in
                guard inside != hovering else { return }
                hovering = inside
                if inside && !reduceMotion {
                    withAnimation(.linear(duration: variant == .steam ? 0.75 : 0.85)) { progress = 1 }
                } else { reset() }
            }
            .onChange(of: reduceMotion) { _, _ in reset() }
            .onDisappear { reset() }
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

/// Original vectors, normalized to 20 points. One animatable value drives a
/// finite gesture, so exiting or Reduce Motion never queues a completion task.
struct CoffeeGlyph: View, Animatable {
    var variant: CoffeeAnimation = .brew
    var progress: Double = 0
    var active = false
    @Environment(\.colorScheme) private var colorScheme
    var animatableData: Double { get { progress } set { progress = newValue } }

    var body: some View {
        let p = min(1, max(0, progress))
        let eased = 1 - pow(1 - p, 3)
        let reveal = variant == .brew || p == 0 ? 1 : eased
        let fill = active ? 0.66 : (variant == .steam ? 0 : 0.63 * eased)
        let wave = variant == .steam ? 0 : sin(p * .pi * 3) * sin(p * .pi) * (variant == .pour ? 1.5 : 1.0)
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
            let steam = variant == .brew ? eased * 0.65 : eased
            for x in [7.0, 10.5] {
                var path = Path(); path.move(to: CGPoint(x: x, y: 5.6))
                path.addCurve(to: CGPoint(x: x, y: 1.7), control1: CGPoint(x: x - 1.8, y: 4.1), control2: CGPoint(x: x + 1.8, y: 3.4))
                context.stroke(path.trimmedPath(from: 0, to: steam), with: .color(ink.opacity(steam)), style: StrokeStyle(lineWidth: 0.9, lineCap: .round))
            }
            if active {
                // Shape + filled coffee identify On without relying on hue.
                let dot = Path(ellipseIn: CGRect(x: 16.2, y: 15.6, width: 2.4, height: 2.4))
                context.fill(dot, with: .color(ink))
            }
        }
    }
}
