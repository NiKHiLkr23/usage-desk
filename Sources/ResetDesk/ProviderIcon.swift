import SwiftUI
import ResetDeskCore

struct ProviderIcon: View {
    let provider: AccountProvider
    var size: CGFloat = 18
    private static let resources: Bundle = {
        if let root = Bundle.main.resourceURL,
           let bundle = Bundle(url: root.appendingPathComponent("ResetDesk_ResetDesk.bundle")) { return bundle }
        return .module
    }()
    static func image(for provider: AccountProvider, size: CGFloat = 18) -> NSImage? {
        guard let url = resources.url(forResource: provider == .codex ? "openai" : "claude", withExtension: "png") else { return nil }
        guard let image = NSImage(contentsOf: url) else { return nil }
        // Native NSMenu reads NSImage's point size, ignoring SwiftUI frame modifiers.
        // Keep the original pixel representation for Retina rendering.
        image.size = NSSize(width: size, height: size)
        image.isTemplate = true
        return image
    }
    static func menuImage(for provider: AccountProvider, colorScheme: ColorScheme) -> NSImage? {
        guard let source = image(for: provider, size: 14) else { return nil }
        source.isTemplate = false
        // SwiftUI's menu bridge can drop template tinting. Render the menu's semantic
        // foreground explicitly while leaving regular provider icons as templates.
        return NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            source.draw(in: rect)
            (colorScheme == .dark ? NSColor.white : NSColor.black).setFill()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
    var body: some View {
        Image(nsImage: Self.image(for: provider, size: size) ?? NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: provider.title)!)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(DeskTheme.text)
            .accessibilityLabel(provider.title)
            .help(provider.title)
    }
}
