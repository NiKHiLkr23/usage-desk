import SwiftUI
import ResetDeskCore

struct AccountLabelEditor: View {
    @ObservedObject var store: AccountStore
    let account: LocalAccount
    @ObservedObject var draft: AccountFormDraft
    @State private var error: String?
    @State private var saved = false
    private var changed: Bool { draft.label.trimmingCharacters(in: .whitespacesAndNewlines) != account.label }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Display name").font(.system(size: 11, weight: .medium))
            HStack(spacing: 8) {
                TextField("Account name", text: $draft.label).textFieldStyle(.roundedBorder).onSubmit { if changed { save() } }
                Button(saved && !changed ? "Saved" : "Save") { save() }
                    .disabled(!changed).buttonStyle(DeskButton())
            }
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(DeskTheme.amber) }
        }.onChange(of: draft.label) { _, _ in error = nil }
    }
    private func save() {
        do {
            try store.renameAccount(account.id, label: draft.label)
            draft.label = store.accounts.first(where: { $0.id == account.id })?.label ?? draft.label
            error = nil
            saved = true
        }
        catch { self.error = error.localizedDescription }
    }
}
