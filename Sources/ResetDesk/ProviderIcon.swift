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
    static func image(for provider: AccountProvider) -> NSImage? {
        guard let url = resources.url(forResource: provider == .codex ? "openai" : "claude", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }
    var body: some View {
        Image(nsImage: Self.image(for: provider) ?? NSImage(systemSymbolName: "questionmark.circle", accessibilityDescription: provider.title)!)
            .renderingMode(.template).resizable().scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(DeskTheme.text)
            .accessibilityLabel(provider.title)
            .help(provider.title)
    }
}
