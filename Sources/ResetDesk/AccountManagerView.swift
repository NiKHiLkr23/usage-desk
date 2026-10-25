import SwiftUI
import ResetDeskCore

struct AccountManagerView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var navigation: DeskNavigation
    private var selection: String? {
        get { navigation.accountSelection }
        nonmutating set { navigation.accountSelection = newValue }
    }
    @State private var removal: LocalAccount?
    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 15) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 5) {
                            ForEach(store.accounts) { account in
                                Button { selection = account.id } label: {
                                    HStack(spacing: 8) {
                                        ProviderIcon(provider: account.provider, size: 16)
                                        VStack(alignment: .leading, spacing: 5) {
                                        Text(account.label).font(.system(size: 12, weight: .medium))
                                        Text(store.states[account.id]?.info?.email ?? (account.managed ? "Sign-in needed" : "Current CLI"))
                                            .font(.system(size: 10)).foregroundStyle(DeskTheme.muted).lineLimit(1).truncationMode(.middle)
                                            .help(store.states[account.id]?.info?.email ?? "Sign-in needed")
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(11)
                                        .contentShape(Rectangle())
                                }.buttonStyle(SidebarAccountButton(selected: selection == account.id))
                                    .accessibilityAddTraits(selection == account.id ? .isSelected : []).id(account.id)
                            }
                        }.padding(.horizontal, 8).padding(.top, 12)
                    }.task(id: selection) {
                        await Task.yield()
                        if let selection { proxy.scrollTo(selection, anchor: .center) }
                    }
                }
                AddAccountMenu(store: store).padding(16)
            }.frame(width: 184).background(DeskTheme.surface)
            Divider().overlay(DeskTheme.line)
            ScrollView {
                if let id = selection, let account = store.accounts.first(where: { $0.id == id }), !account.managed, account.provider == .codex {
                    VStack(alignment: .leading, spacing: 18) {
                        AccountLabelEditor(store: store, account: account, draft: navigation.draft(for: account))
                        Label("Codex CLI", systemImage: "person.crop.circle").font(.system(size: 13, weight: .medium))
                        Text(store.states[id]?.info?.email ?? "No account email reported").textSelection(.enabled)
                        if let error = store.states[id]?.error { Text(error).foregroundStyle(DeskTheme.amber) }
                        Text("This is the sign-in already used by your Codex CLI. Usage desk reads it without replacing it.").foregroundStyle(DeskTheme.muted)
                        Text("To sign in or change it, run codex login in Terminal. For your other Chrome accounts, use Add account to keep their sign-ins separate.").foregroundStyle(DeskTheme.muted)
                        Button("View this account") { store.selectedID = id; AppWindows.showDashboard(store) }.buttonStyle(AccentButton())
                        Text(account.home).font(.system(size: 10, design: .monospaced)).foregroundStyle(DeskTheme.muted).textSelection(.enabled)
                    }.font(.system(size: 12)).padding(20).frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    AddAccountView(store: store, account: store.accounts.first { $0.id == selection },
                                   draft: navigation.draft(for: store.accounts.first { $0.id == selection }),
                                   created: { navigation.createdAccount($0) }, remove: { removal = $0 })
                        .id(selection ?? "new").padding(20)
                }
            }.frame(maxWidth: .infinity)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).background(DeskTheme.background).foregroundStyle(DeskTheme.text).tint(DeskTheme.text).buttonStyle(DeskButton()).deskAppearance()
            .alert("Remove this profile?", isPresented: Binding(get: { removal != nil }, set: { if !$0 { removal = nil } })) {
                Button("Cancel", role: .cancel) { removal = nil }
                Button("Remove", role: .destructive) {
                    guard let account = removal else { return }
                    Task { do { try await store.removeAccount(account.id); selection = nil; removal = nil } catch { store.message = error.localizedDescription } }
                }
            } message: { Text("This stops tracking the account. Its local CLI sign-in is retained.") }
    }
}

struct AddAccountView: View {
    @ObservedObject var store: AccountStore
    let account: LocalAccount?
    @ObservedObject var draft: AccountFormDraft
    var created: (String) -> Void
    var remove: (LocalAccount) -> Void
    @State private var profileID: String?
    @State private var busy = false
    @State private var error: String?
    private var currentID: String? { profileID ?? account?.id }
    private var pending: PendingLogin? { store.pendingLogin?.accountID == currentID ? store.pendingLogin : nil }
    private var state: AccountState? { currentID.flatMap { store.states[$0] } }
    private var mismatched: Bool {
        guard let actual = state?.info?.email, !draft.email.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return actual.caseInsensitiveCompare(draft.email.trimmingCharacters(in: .whitespaces)) != .orderedSame
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Text(account == nil && profileID == nil ? "Add account" : "Edit account").font(.system(size: 23, weight: .medium)).tracking(-0.5)
                Spacer()
            }
            if currentID == nil {
                HStack(spacing: 10) {
                    ForEach(AccountProvider.allCases) { provider in
                        Button { draft.provider = provider } label: {
                            HStack(spacing: 8) { ProviderIcon(provider: provider, size: 20); Text(provider.title).font(.system(size: 12, weight: .medium)); Spacer(); if draft.provider == provider { Image(systemName: "checkmark").font(.system(size: 10)) } }
                                .padding(12).frame(maxWidth: .infinity).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .background(draft.provider == provider ? DeskTheme.hover : DeskTheme.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(draft.provider == provider ? DeskTheme.text : DeskTheme.line, lineWidth: 1))
                            .accessibilityAddTraits(draft.provider == provider ? .isSelected : [])
                    }
                }
            }
            if let account { AccountLabelEditor(store: store, account: account, draft: draft) }
            if (account?.provider ?? draft.provider) == .claude {
                ClaudeAccountConnectionView(store: store, account: account, draft: draft, created: created, remove: remove)
            } else {
            Text("Choose a Chrome profile. Sign in with the OpenAI account you want to track.").font(.system(size: 12)).foregroundStyle(DeskTheme.muted)
            if currentID == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Account label").font(.system(size: 11, weight: .medium))
                    TextField("Personal, work, side projects…", text: $draft.label).textFieldStyle(.roundedBorder)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Open sign-in with").font(.system(size: 11, weight: .medium))
                Picker("Chrome profile", selection: $draft.chrome) {
                    Text("Default browser / choose manually").tag("default-browser")
                    ForEach(store.chromeProfiles) { profile in Text(profile.displayName).tag(profile.id) }
                }.labelsHidden().frame(maxWidth: .infinity, alignment: .leading)
                    .disabled(pending != nil || busy)
                    .onChange(of: draft.chrome) { _, id in if currentID == nil, let profile = store.chromeProfiles.first(where: { $0.id == id }) { draft.email = profile.email ?? ""; if draft.label.isEmpty { draft.label = profile.name } } }
                Button("Reload Chrome profiles") { store.reloadChromeProfiles() }.buttonStyle(DeskButton()).font(.system(size: 10))
            }
            if currentID == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Expected OpenAI email (optional)").font(.system(size: 11, weight: .medium))
                    TextField("you@example.com", text: $draft.email).textFieldStyle(.roundedBorder)
                    Text("Chrome’s Google email and your OpenAI email can differ. The authenticated OpenAI email is shown after sign-in.").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                }
            }
            if let pending {
                VStack(alignment: .leading, spacing: 12) {
                    Label(pending.url == nil ? "Preparing sign-in…" : "Finish sign-in in your browser", systemImage: "person.crop.circle.badge.clock").font(.system(size: 13, weight: .medium))
                    Text(pending.url == nil ? "Requesting a secure sign-in link from Codex. You can cancel and retry if needed." : "Choose the intended account on OpenAI’s page. Your Chrome profile and OpenAI account can use different emails.").font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
                    HStack {
                        Button("Open sign-in again") { store.openPendingSignIn() }.buttonStyle(AccentButton()).disabled(pending.url == nil)
                        CopyFeedbackButton(title: "Copy sign-in link") { pending.url?.absoluteString }
                            .disabled(pending.url == nil)
                    }
                    Button("Cancel sign-in") { Task { await store.cancelSignIn() } }.buttonStyle(DeskButton()).font(.system(size: 11))
                }.deskCard()
            } else if let actual = state?.info?.email {
                VStack(alignment: .leading, spacing: 7) {
                    Label(mismatched ? "Different account connected" : "Authenticated with OpenAI", systemImage: mismatched ? "exclamationmark.triangle" : "checkmark.seal")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(mismatched ? DeskTheme.amber : DeskTheme.status)
                    Text(actual).font(.system(size: 13)).textSelection(.enabled)
                    Text(mismatched ? "Expected \(draft.email). Reconnect and choose the intended OpenAI account in your browser." : "\(shortPlan(state?.info?.planType)) · Sign-in remains saved when Chrome closes.")
                        .font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
                }.deskCard()
                HStack {
                    Button("View usage") { if let id = currentID { store.selectedID = id }; AppWindows.showDashboard(store) }.buttonStyle(AccentButton())
                    Button("Reconnect") { signIn() }.disabled(busy || store.pendingLogin != nil)
                }
            } else {
                Button { signIn() } label: { HStack { if busy { ProgressView().controlSize(.mini) }; Text(busy ? "Preparing sign-in…" : "Sign in with OpenAI"); Image(systemName: "arrow.up.right") } }
                    .buttonStyle(AccentButton()).disabled(busy || (currentID == nil && draft.label.trimmingCharacters(in: .whitespaces).isEmpty) || store.pendingLogin != nil)
                if store.pendingLogin != nil { Text("Finish or cancel the other pending account sign-in first.").font(.system(size: 11)).foregroundStyle(DeskTheme.amber) }
            }
            if let error = error ?? state?.error { Text(error).font(.system(size: 11)).foregroundStyle(DeskTheme.amber).textSelection(.enabled) }
            Text("OpenAI handles sign-in in your browser. Credentials stay on this Mac.").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            if let account { Button("Remove from Usage desk", role: .destructive) { remove(account) }.font(.system(size: 11)) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)

    }

    private func signIn() {
        busy = true; error = nil
        Task {
            do {
                let browser = store.chromeProfiles.contains(where: { $0.id == draft.chrome }) ? draft.chrome : nil
                let id: String
                if let currentID { id = currentID }
                else {
                    id = try store.createAccount(label: draft.label, chromeProfile: browser, expectedEmail: draft.email)
                    profileID = id
                    created(id)
                }
                try await store.beginSignIn(id, chromeProfile: browser)
            } catch is CancellationError { /* The user canceled or replaced this attempt. */ }
            catch { self.error = error.localizedDescription }
            busy = false
        }
    }
}
