import SwiftUI
import AppKit

enum DeskAppearance: String, CaseIterable {
    case system, light, dark
    var next: Self { self == .system ? .light : self == .light ? .dark : .system }
    var title: String { rawValue.capitalized }
    var scheme: ColorScheme? { self == .system ? nil : self == .dark ? .dark : .light }
    var appKitAppearance: NSAppearance? {
        self == .system ? nil : NSAppearance(named: self == .dark ? .darkAqua : .aqua)
    }
    @MainActor func applyToApp(window: NSWindow? = nil) {
        NSApp.appearance = appKitAppearance
        window?.appearance = appKitAppearance ?? NSApp.effectiveAppearance
    }
}

enum DeskTheme {
    private static func color(_ name: String, light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: NSColor.Name(name)) { appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Double((hex >> 16) & 255) / 255, green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, alpha: 1)
        })
    }
    static let background = color("desk.panel", light: 0xffffff, dark: 0x171717)
    static let surface = color("desk.surface", light: 0xf7f7f7, dark: 0x202020)
    static let hover = color("desk.hover", light: 0xf0f0f0, dark: 0x252525)
    static let line = color("desk.border", light: 0xe2e2e2, dark: 0x333333)
    static let text = color("desk.text", light: 0x171717, dark: 0xf4f4f4)
    static let muted = color("desk.muted", light: 0x686868, dark: 0xa2a2a2)
    static let accent = color("desk.quota", light: 0x577b45, dark: 0xc9e6b9)
    static let status = color("desk.status", light: 0x527b40, dark: 0xc9e6b9)
    static let track = color("desk.track", light: 0xe2e2e2, dark: 0x3b3b3b)
    static let button = color("desk.button", light: 0x171717, dark: 0xf2f2f2)
    static let buttonText = color("desk.buttonText", light: 0xffffff, dark: 0x171717)
    static let amber = color("desk.warning", light: 0x946200, dark: 0xf0bb62)
    static let danger = color("desk.danger", light: 0xb42318, dark: 0xff9b91)
    static let claude = Color(nsColor: claudeColor)
    static let claudeColor = NSColor(srgbRed: 217.0 / 255, green: 119.0 / 255, blue: 87.0 / 255, alpha: 1)
    static func quota(_ remaining: Double) -> Color {
        remaining <= 0 ? danger : remaining <= 20 ? amber : accent
    }
}

private struct DeskAppearanceModifier: ViewModifier {
    @AppStorage("usageDeskAppearance") private var appearance = DeskAppearance.system.rawValue
    @Environment(\.colorScheme) private var inheritedScheme
    private var choice: DeskAppearance { DeskAppearance(rawValue: appearance) ?? .system }
    func body(content: Content) -> some View {
        content.environment(\.colorScheme, choice.scheme ?? inheritedScheme)
            .background(DeskAppearanceBridge(choice: choice).allowsHitTesting(false).accessibilityHidden(true))
            .onChange(of: appearance, initial: true) { _, _ in
                choice.applyToApp()
            }
    }
}

/// Apply appearance to the owning popover, including when it first attaches.
private struct DeskAppearanceBridge: NSViewRepresentable {
    let choice: DeskAppearance
    func makeNSView(context: Context) -> DeskAppearanceView {
        let view = DeskAppearanceView()
        view.choice = choice
        return view
    }
    func updateNSView(_ view: DeskAppearanceView, context: Context) {
        view.choice = choice
        view.synchronize()
    }
}

private final class DeskAppearanceView: NSView {
    var choice: DeskAppearance = .system
    private var appearanceObservation: NSKeyValueObservation?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        appearanceObservation = nil
        guard window != nil else { return }
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { [weak self] _, _ in
            Task { @MainActor in
                guard let self, self.choice == .system else { return }
                self.synchronize()
            }
        }
        synchronize()
    }
    func synchronize() {
        // A popover can inherit its status-item anchor's appearance on macOS 15.
        // Resolve System from the app, whose override is cleared, instead.
        let appearance = choice.appKitAppearance ?? NSApp.effectiveAppearance
        guard let window, window.appearance?.name != appearance.name else { return }
        window.appearance = appearance
    }
}

struct DeskCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(14).background(DeskTheme.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(DeskTheme.line, lineWidth: 1))
    }
}
extension View {
    func deskCard() -> some View { modifier(DeskCard()) }
    func deskAppearance() -> some View { modifier(DeskAppearanceModifier()) }
}

struct DeskButton: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View { StyledLabel(configuration: configuration, primary: primary) }
    private struct StyledLabel: View {
        let configuration: Configuration
        let primary: Bool
        @Environment(\.isEnabled) private var enabled
        @State private var hovering = false
        var body: some View {
            configuration.label.font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 13).padding(.vertical, 9)
                .foregroundStyle(primary ? DeskTheme.buttonText : DeskTheme.text)
                .background(primary ? DeskTheme.button : hovering ? DeskTheme.hover : DeskTheme.background, in: Capsule())
                .overlay(Capsule().stroke(primary ? .clear : DeskTheme.line, lineWidth: 1))
                .contentShape(Capsule()).opacity(enabled ? configuration.isPressed ? 0.75 : 1 : 0.45)
                .onHover { hovering = $0 }
        }
    }
}
struct AccentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { DeskButton(primary: true).makeBody(configuration: configuration) }
}
struct DeskIconButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View { IconLabel(configuration: configuration) }
    private struct IconLabel: View {
        let configuration: Configuration
        @State private var hovering = false
        @Environment(\.isEnabled) private var enabled
        var body: some View {
            configuration.label.font(.system(size: 14, weight: .regular)).frame(width: 32, height: 32)
                .foregroundStyle(hovering ? DeskTheme.text : DeskTheme.muted)
                .background(hovering || configuration.isPressed ? DeskTheme.hover : .clear, in: Circle())
                .contentShape(Circle()).opacity(enabled ? 1 : 0.45).onHover { hovering = $0 }
        }
    }
}

struct AppearanceButton: View {
    @AppStorage("usageDeskAppearance") private var appearance = DeskAppearance.system.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hovering = false
    @StateObject private var revealOrigin = ThemeRevealOrigin()
    private var choice: DeskAppearance { DeskAppearance(rawValue: appearance) ?? .system }
    var body: some View {
        Button {
            let next = choice.next
            ThemeRevealTransition.shared.perform(from: revealOrigin.view) {
                appearance = next.rawValue
                next.applyToApp(window: revealOrigin.view?.window)
            }
        } label: {
            ZStack {
                Image(systemName: "display").opacity(choice == .system ? 1 : 0).scaleEffect(choice == .system ? 1 : 0.65)
                Image(systemName: "sun.max").rotationEffect(.degrees(hovering && !reduceMotion ? 360 : 0))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.5), value: hovering)
                    .opacity(choice == .light ? 1 : 0).scaleEffect(choice == .light ? 1 : 0.65)
                ZStack {
                    Image(systemName: "moon").rotationEffect(.degrees(hovering && !reduceMotion ? -12 : 0))
                    ForEach(0..<3) { index in
                        Image(systemName: "sparkle").font(.system(size: 4))
                            .offset(x: CGFloat(-5 + index * 3), y: CGFloat(-7 + index * 4))
                            .opacity(hovering ? 1 : 0).scaleEffect(hovering ? 1 : 0.1)
                            .animation(reduceMotion ? nil : .easeOut(duration: 0.3).delay(Double(index) * 0.06), value: hovering)
                    }
                }.animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: hovering)
                    .opacity(choice == .dark ? 1 : 0).scaleEffect(choice == .dark ? 1 : 0.65)
            }.animation(reduceMotion ? nil : .easeOut(duration: 0.26), value: appearance)
        }.buttonStyle(DeskIconButton()).background(ThemeRevealAnchor(origin: revealOrigin))
            .onHover { hovering = $0 }
            .accessibilityLabel("Theme: \(choice.title). Switch to \(choice.next.rawValue) mode.")
            .help("\(choice.title) theme · Click for \(choice.next.rawValue)")
    }
}

struct DeskTabs<Value: Hashable>: View {
    @Binding var selection: Value
    let items: [(Value, String, String)]
    var onSelect: ((Value) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.0) { value, title, symbol in
                Button { if let onSelect { onSelect(value) } else { selection = value } } label: {
                    Label(title, systemImage: symbol).font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 9)
                        .foregroundStyle(selection == value ? DeskTheme.buttonText : DeskTheme.muted)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: selection == value)
                        .contentShape(Capsule())
                }.buttonStyle(.plain).accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }.background {
            GeometryReader { geometry in
                if let index = items.firstIndex(where: { $0.0 == selection }) {
                    let gap: CGFloat = 4
                    let width = max(0, (geometry.size.width - gap * CGFloat(items.count - 1)) / CGFloat(items.count))
                    // One persistent shape moves behind all buttons. Its identity
                    // never changes when selection moves between native controls.
                    Capsule().fill(DeskTheme.button)
                        .frame(width: width, height: geometry.size.height)
                        .offset(x: CGFloat(index) * (width + gap))
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: selection)
                        .allowsHitTesting(false)
                }
            }
        }.padding(4).background(DeskTheme.surface, in: Capsule())
    }
}

func countdown(_ date: Date?, now: Date = Date()) -> String {
    guard let date else { return "Not reported" }
    let minutes = Int(ceil(date.timeIntervalSince(now) / 60))
    guard minutes > 0 else { return "Awaiting update" }
    if minutes < 60 { return "\(minutes)m" }
    if minutes < 1440 { return "\(minutes / 60)h \(minutes % 60)m" }
    return "\(minutes / 1440)d \((minutes % 1440) / 60)h"
}
func shortPlan(_ value: String?) -> String { value?.replacingOccurrences(of: "_", with: " ").capitalized ?? "Plan unknown" }

/// The entire padded account row responds, including the empty trailing area.
struct SidebarAccountButton: ButtonStyle {
    let selected: Bool
    func makeBody(configuration: Configuration) -> some View {
        Row(configuration: configuration, selected: selected)
    }
    private struct Row: View {
        let configuration: Configuration
        let selected: Bool
        @State private var hovering = false
        var body: some View {
            configuration.label
                .background(selected || configuration.isPressed ? DeskTheme.line : hovering ? DeskTheme.hover : .clear,
                            in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
        }
    }
}
