import SwiftUI

/// Open the shared form directly; provider selection lives on that screen.
struct AddAccountButton: View {
    @ObservedObject var store: AccountStore
    var body: some View {
        Button { AppWindows.addAccount(store) } label: {
            Label("Add account", systemImage: "plus")
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Capsule())
        }.buttonStyle(.plain)
            .overlay(Capsule().strokeBorder(DeskTheme.line, style: StrokeStyle(lineWidth: 1, dash: [3, 3])).allowsHitTesting(false))
            .help("Add account")
    }
}
