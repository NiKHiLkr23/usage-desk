import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var navigation: DeskNavigation
    private var cliPath: String {
        get { navigation.executableDraft ?? store.executablePath }
        nonmutating set { navigation.executableDraft = newValue }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            Text("Theme follows your Mac by default. Use the icon to override it.").font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
            Toggle("Launch Usage desk at login", isOn: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }))
            Toggle("Show quota in menu bar", isOn: $store.showMenuPercent)
            Picker("Refresh usage", selection: $store.refreshInterval) { Text("Every minute").tag(60); Text("Every 2 minutes").tag(120); Text("Every 5 minutes").tag(300) }
            VStack(alignment: .leading, spacing: 8) {
                Text("Codex CLI executable").font(.system(size: 11, weight: .medium))
                HStack {
                    TextField("/path/to/codex", text: Binding(get: { cliPath }, set: { cliPath = $0 })).textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced))
                    Button("Choose…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true; panel.allowsMultipleSelection = false
                        if panel.runModal() == .OK, let url = panel.url { cliPath = url.path }
                    }
                }
                Button("Save and reconnect") {
                    guard FileManager.default.isExecutableFile(atPath: cliPath) else { store.message = "Choose an executable Codex CLI file."; return }
                    store.executablePath = cliPath
                    Task { await store.resetConnections() }
                }.disabled(store.pendingLogin != nil)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude CLI executable").font(.system(size: 11, weight: .medium))
                HStack {
                    TextField("/path/to/claude", text: Binding(get: { navigation.claudeExecutableDraft ?? store.claudeExecutablePath }, set: { navigation.claudeExecutableDraft = $0 }))
                        .textFieldStyle(.roundedBorder).font(.system(size: 11, design: .monospaced))
                    Button("Choose…") {
                        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.canChooseFiles = true
                        if panel.runModal() == .OK { navigation.claudeExecutableDraft = panel.url?.path }
                    }
                }
                Button("Save and reconnect") {
                    let path = navigation.claudeExecutableDraft ?? store.claudeExecutablePath
                    guard FileManager.default.isExecutableFile(atPath: path) else { store.message = "Choose an executable Claude CLI file."; return }
                    store.claudeExecutablePath = path
                    Task { await store.resetConnections() }
                }.disabled(store.pendingLogin != nil)
            }
            if let message = store.message { Text(message).font(.system(size: 11)).foregroundStyle(DeskTheme.amber).textSelection(.enabled) }
            Text("Sign-ins are managed by Codex and Claude CLI. Usage Desk has no analytics or cloud account.")
                .font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            HStack {
                Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")")
                Spacer()
                Link("Release notes", destination: URL(string: "https://github.com/NiKHiLkr23/usage-desk/releases")!)
            }.font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
        }.font(.system(size: 12)).padding(.top, 12).frame(maxWidth: .infinity, alignment: .leading).background(DeskTheme.background).foregroundStyle(DeskTheme.text).tint(DeskTheme.text).buttonStyle(DeskButton()).deskAppearance()
    }
}
