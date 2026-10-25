import SwiftUI
import ResetDeskCore

struct ClaudeAccountConnectionView: View {
    @ObservedObject var store: AccountStore
    let account: LocalAccount?
    @ObservedObject var draft: AccountFormDraft
    var created: (String) -> Void
    var remove: (LocalAccount) -> Void
    @State private var error: String?
    private var state: AccountState { store.states[account?.id ?? ""] ?? AccountState() }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            Text("Connect an existing Claude CLI account.")
                .font(.system(size: 12)).foregroundStyle(DeskTheme.muted)
            if account == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account label").font(.system(size: 11, weight: .medium))
                    TextField("Personal, work…", text: $draft.label).textFieldStyle(.roundedBorder)
                }
            } else {
                HStack(spacing: 8) { ProviderIcon(provider: .claude); Text(account?.label ?? "Claude").font(.system(size: 15, weight: .medium)) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude CLI profile").font(.system(size: 11, weight: .medium))
                HStack {
                    TextField("~/.claude", text: $draft.claudeHome).textFieldStyle(.roundedBorder)
                        .font(.system(size: 11, design: .monospaced)).disabled(account != nil)
                    if account == nil {
                        Button("Choose…") {
                            let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url { draft.claudeHome = url.path }
                        }
                    }
                }
                Text("The default is ~/.claude. If T3 uses a custom Claude configuration directory, choose that same folder.")
                    .font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            }
            if account == nil {
                Button("Connect Claude account") {
                    do {
                        let id = try store.connectClaude(label: draft.label, home: draft.claudeHome)
                        created(id)
                        Task { await store.refresh(id) }
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(AccentButton()).disabled(draft.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                copyCommandButton
                Text("Not signed in yet? Run the copied command in Terminal, finish Claude’s browser sign-in, then connect here.")
                    .font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            } else if state.isLoading {
                HStack(spacing: 8) { ProgressView().controlSize(.small); Text("Reading Claude usage…") }.font(.system(size: 12))
            } else if let info = state.info, !state.signedOut {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Claude CLI connected", systemImage: "checkmark.seal").foregroundStyle(DeskTheme.status)
                    if let email = info.email { Text(email).textSelection(.enabled) }
                    Text(shortPlan(info.planType)).foregroundStyle(DeskTheme.muted)
                }.font(.system(size: 12)).deskCard()
                HStack {
                    Button("View usage") { if let account { store.selectedID = account.id }; AppWindows.showDashboard(store) }.buttonStyle(AccentButton())
                    Button("Refresh") { if let account { Task { await store.refresh(account.id) } } }
                }
            } else {
                Text("Sign in through Claude CLI, then refresh here.").font(.system(size: 12, weight: .medium))
                copyCommandButton
                Text("Paste the command in Terminal. Claude opens its own browser sign-in; Usage Desk never asks for your password.")
                    .font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                Button("Refresh connection") { if let account { Task { await store.refresh(account.id) } } }.buttonStyle(AccentButton())
            }
            if let error = error ?? state.error {
                if state.info != nil { copyCommandButton }
                Text(error).font(.system(size: 11)).foregroundStyle(DeskTheme.amber).textSelection(.enabled)
            }
            Text("Usage Desk reads limits through Claude CLI without sending prompts. Your T3 account and Claude settings stay in place.")
                .font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            if let account { Button("Remove from Usage desk", role: .destructive) { remove(account) }.font(.system(size: 11)) }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var copyCommandButton: some View {
        CopyFeedbackButton(title: "Copy sign-in command") { signInCommand }
    }
    private var signInCommand: String {
        let quote: (String) -> String = { "'" + $0.replacingOccurrences(of: "'", with: "'\"'\"'") + "'" }
        return "CLAUDE_CONFIG_DIR=\(quote(account?.home ?? draft.claudeHome)) \(quote(store.claudeExecutablePath)) auth login"
    }
}
