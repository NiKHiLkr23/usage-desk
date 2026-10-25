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
        guard let pixels = source.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: 28, height: 28, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        // SwiftUI's native-menu bridge can drop template tinting. Rasterize at
        // Retina size in sRGB so the brand orange survives the bridge unchanged.
        let rect = CGRect(x: 0, y: 0, width: 28, height: 28)
        context.draw(pixels, in: rect)
        context.setBlendMode(.sourceAtop)
        let color = provider == .claude ? DeskTheme.claudeColor : colorScheme == .dark ? NSColor.white : NSColor.black
        context.setFillColor(color.cgColor)
        context.fill(rect)
        guard let tinted = context.makeImage() else { return nil }
        return NSImage(cgImage: tinted, size: NSSize(width: 14, height: 14))
    }

    var body: some View {
        Image(nsImage: Self.image(for: provider, size: size) ?? NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: provider.title)!)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(provider == .claude ? DeskTheme.claude : DeskTheme.text)
            .accessibilityLabel(provider.title)
            .help(provider.title)
    }
}
