import SwiftUI
import ResetDeskCore

/// Both entry points preselect the provider while preserving an unfinished draft.
struct AddAccountMenu: View {
    @ObservedObject var store: AccountStore
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Menu {
            ForEach(AccountProvider.allCases) { provider in
                Button { AppWindows.addAccount(store, provider: provider) } label: {
                    Label { Text(provider.title) } icon: {
                        if let image = ProviderIcon.menuImage(for: provider, colorScheme: colorScheme) {
                            Image(nsImage: image).renderingMode(.original)
                        }
                    }
                }
            }
        } label: {
            Label("Add account", systemImage: "plus")
                .font(.system(size: 11, weight: .medium))
        }.menuStyle(.borderlessButton).menuIndicator(.hidden)
            .frame(maxWidth: .infinity, minHeight: 36).contentShape(Capsule())
            .overlay(Capsule().strokeBorder(DeskTheme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).allowsHitTesting(false))
            .help("Choose Codex or Claude")
    }
}
