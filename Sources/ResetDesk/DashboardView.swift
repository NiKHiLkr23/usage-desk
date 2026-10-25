import SwiftUI
import ResetDeskCore

struct DashboardView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var navigation: DeskNavigation
    @State private var confirmingQuit = false
    @Environment(\.colorScheme) private var colorScheme
    private var tab: String { navigation.usageTab }
    private var resetTab: String {
        get { navigation.resetTab }
        nonmutating set { navigation.resetTab = newValue }
    }
    private var state: AccountState { store.selectedState }

    var body: some View {
        VStack(spacing: 0) {
            accountSelector.padding(.horizontal, 16).padding(.bottom, 14)
            DeskTabs(selection: $navigation.usageTab, items: [("usage", "Usage", "chart.bar"), ("resets", "Resets\(state.usage?.rateLimitResetCredits.map { " · \($0.availableCount)" } ?? "")", "arrow.counterclockwise"), ("accounts", "Accounts", "person.2")])
                .padding(.horizontal, 16).padding(.bottom, 14)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if tab == "accounts" {
                            quickAccounts
                        } else {
                            notices
                            if let usage = state.usage {
                                if tab == "usage" { usageContent(usage) }
                                else { resetsContent(usage) }
                            } else if state.isLoading {
                                HStack(spacing: 9) { ProgressView().controlSize(.small); Text("Reading usage…") }.font(.system(size: 12)).padding(.vertical, 40).frame(maxWidth: .infinity)
                            } else if !state.signedOut && !state.unsupported && state.error == nil {
                                Text("No usage reported yet.").font(.system(size: 12)).foregroundStyle(DeskTheme.muted).frame(maxWidth: .infinity).padding(.vertical, 40)
                            }
                        }
                    }.padding(.horizontal, 16).padding(.bottom, 16).frame(maxWidth: .infinity, alignment: .leading)
                }.task(id: tab) {
                    if tab == "accounts", let id = navigation.accountScrollID {
                        await Task.yield()
                        proxy.scrollTo(id, anchor: .top)
                    }
                }
            }.frame(maxHeight: .infinity)
            Rectangle().fill(DeskTheme.line).frame(height: 1)
            footer
        }.foregroundStyle(DeskTheme.text).background(DeskTheme.background)
            .onChange(of: store.selectedID) { _, id in Task { await store.refresh(id) } }
            .alert("Quit Usage desk?", isPresented: $confirmingQuit) {
                Button("Cancel", role: .cancel) { }
                Button("Quit", role: .destructive) { store.shutdown(); NSApp.terminate(nil) }
            } message: {
                Text(store.pendingLogin == nil
                     ? "Usage updates will stop until you reopen the app. Your saved accounts will stay connected."
                     : "Your pending sign-in will be canceled and usage updates will stop. Your saved accounts will stay connected.")
            }
    }

    private var quickAccounts: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Your accounts").font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
                Text("\(store.accounts.count) profiles").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                Spacer()
                Button("Manage accounts") { AppWindows.showAccounts(store, selectedID: store.selected?.id) }
                    .buttonStyle(.plain).font(.system(size: 11, weight: .medium))
            }.padding(.vertical, 6)
            TimelineView(.periodic(from: .now, by: 30)) { context in
                VStack(spacing: 6) {
                    ForEach(store.accounts) { account in
                        quickAccountRow(account, now: context.date).id(account.id)
                    }
                }.scrollTargetLayout()
            }
            AddAccountMenu(store: store)
                .padding(.top, 2)
        }
    }

    private func quickAccountRow(_ account: LocalAccount, now: Date) -> some View {
        let summary = AccountQuickSummary(state: store.states[account.id], signingIn: store.pendingLogin?.accountID == account.id, now: now)
        return HStack(spacing: 0) {
            Button { store.selectedID = account.id; navigation.showUsage() } label: {
                HStack(spacing: 10) {
                    ProviderIcon(provider: account.provider, size: 18)
                        .frame(width: 30, height: 30)
                        .background(DeskTheme.surface, in: RoundedRectangle(cornerRadius: 8)).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.label).font(.system(size: 11, weight: .medium)).lineLimit(1)
                        Text(store.states[account.id]?.info?.email ?? "Sign-in needed")
                            .font(.system(size: 9)).foregroundStyle(DeskTheme.muted).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    if store.selected?.id == account.id {
                        Image(systemName: "checkmark").font(.system(size: 10, weight: .medium)).accessibilityHidden(true)
                    }
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(summary.title).font(.system(size: 10, weight: .medium)).foregroundStyle(summary.color)
                        if let detail = summary.detail { Text(detail).font(.system(size: 9)).foregroundStyle(DeskTheme.muted) }
                    }.monospacedDigit().fixedSize()
                }.padding(.leading, 10).padding(.trailing, 4).padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(SidebarAccountButton(selected: false))
                .accessibilityAddTraits(store.selected?.id == account.id ? .isSelected : [])
                .accessibilityLabel("\(account.provider.title), \(account.label), \(summary.title), \(summary.detail ?? "")")
                .help("View usage for \(account.label)")
            AnimatedDeskIconButton(kind: .gear, title: "Account settings for \(account.label)") {
                navigation.accountScrollID = account.id
                AppWindows.showAccounts(store, selectedID: account.id)
            }.padding(.trailing, 4)
        }.background(store.selected?.id == account.id ? DeskTheme.line : .clear, in: RoundedRectangle(cornerRadius: 8))
            .contextMenu {
                Button("View usage") { store.selectedID = account.id; navigation.showUsage() }
                Button("Edit account…") { navigation.accountScrollID = account.id; AppWindows.showAccounts(store, selectedID: account.id) }
                Button("Reconnect…") { AppWindows.showAccounts(store, selectedID: account.id) }
            }
    }

    private var accountSelector: some View {
        HStack(spacing: 10) {
            ProviderIcon(provider: store.selected?.provider ?? .codex, size: 21)
                .frame(width: 34, height: 34).background(DeskTheme.surface, in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 3) {
                Menu {
                    ForEach(store.accounts) { account in
                        Button { store.selectedID = account.id } label: {
                            Label {
                                Text(account.label)
                            } icon: {
                                if let image = ProviderIcon.menuImage(for: account.provider, colorScheme: colorScheme) {
                                    Image(nsImage: image).renderingMode(.original)
                                } else { Image(systemName: "person.crop.circle") }
                            }
                        }.accessibilityLabel("\(account.provider.title), \(account.label)")
                    }
                    Divider()
                    Button("Edit this account…", systemImage: "pencil") { AppWindows.showAccounts(store, selectedID: store.selected?.id) }
                    Menu("Add account", systemImage: "plus") {
                        ForEach(AccountProvider.allCases) { provider in
                            Button(provider.title) { AppWindows.addAccount(store, provider: provider) }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(store.selected?.label ?? "Choose account").lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 8, weight: .semibold))
                    }.font(.system(size: 12, weight: .medium))
                }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize(horizontal: false, vertical: true).accessibilityLabel("Selected account")
                Text(state.info?.email ?? (state.info != nil ? "Email not reported" : state.signedOut ? "Sign-in needed" : "Reading account…"))
                    .font(.system(size: 10)).foregroundStyle(DeskTheme.muted).lineLimit(1).textSelection(.enabled)
            }
            Spacer(minLength: 4)
            Text(shortPlan(state.info?.planType)).font(.system(size: 9, weight: .medium)).foregroundStyle(DeskTheme.muted)
                .padding(.horizontal, 6).padding(.vertical, 3).overlay(RoundedRectangle(cornerRadius: 4).stroke(DeskTheme.line, lineWidth: 1))
        }
    }

    @ViewBuilder private var notices: some View {
        if let expected = store.selected?.expectedEmail, let actual = state.info?.email, expected.caseInsensitiveCompare(actual) != .orderedSame {
            notice("Different account connected", detail: "Connected as \(actual); expected \(expected). Reconnect in Accounts.")
        }
        if let message = store.message {
            HStack(alignment: .top) {
                Text(message).font(.system(size: 11)).textSelection(.enabled)
                Spacer(minLength: 4)
                Button { store.message = nil } label: { Image(systemName: "xmark") }.buttonStyle(DeskIconButton()).accessibilityLabel("Dismiss message")
            }.deskCard()
        }
        if let error = state.error {
            notice(state.usage == nil ? "Needs attention" : "Showing last known usage", detail: error + (state.usage == nil ? "" : " These values are stale; refresh to confirm replenishment."))
        }
        if store.pendingLogin?.accountID == store.selected?.id {
            VStack(alignment: .leading, spacing: 10) {
                Text("Waiting for OpenAI sign-in").font(.system(size: 12, weight: .medium))
                Button("Continue sign-in") { store.openPendingSignIn() }.buttonStyle(AccentButton())
            }.frame(maxWidth: .infinity, alignment: .leading).deskCard()
        } else if state.signedOut || state.unsupported {
            VStack(alignment: .leading, spacing: 10) {
                Text(state.unsupported ? (store.selected?.provider == .claude ? "Claude subscription required" : "ChatGPT sign-in required") : "Connect this account").font(.system(size: 13, weight: .medium))
                Text(store.selected?.provider == .claude ? "Sign in to the Claude CLI with your Pro or Max account, then refresh." : state.unsupported ? "API keys do not report plan usage." : "Choose a Chrome profile and sign in with OpenAI.").font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
                Button("Manage accounts") { AppWindows.showAccounts(store, selectedID: store.selected?.id) }.buttonStyle(AccentButton())
            }.frame(maxWidth: .infinity, alignment: .leading).deskCard()
        }
    }

    private func notice(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: "exclamationmark.triangle").font(.system(size: 12, weight: .medium)).foregroundStyle(DeskTheme.amber)
            Text(detail).font(.system(size: 11)).foregroundStyle(DeskTheme.muted).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading).deskCard()
    }

    @ViewBuilder private func usageContent(_ usage: UsageSnapshot) -> some View {
        if usage.ordinaryUsageAllowed == false { Label("Included usage is currently blocked", systemImage: "pause.circle").font(.system(size: 11)) }
        let meters = usage.meters
        if meters.isEmpty { Text("No usage windows reported.").font(.system(size: 12)).foregroundStyle(DeskTheme.muted).deskCard() }
        else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                ForEach(meters) { meter in MeterView(meter: meter) }
            }
        }
        if store.selected?.provider != .claude {
        Button { navigation.usageTab = "resets"; resetTab = "earned" } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise").foregroundStyle(DeskTheme.muted)
                Text("Earned resets"); Spacer()
                Text(usage.rateLimitResetCredits.map { "\($0.availableCount) available" } ?? "Not reported")
                Image(systemName: "chevron.right").font(.system(size: 9))
            }.font(.system(size: 11)).padding(.horizontal, 1)
        }.buttonStyle(DeskButton())
        }
    }

    private func resetsContent(_ usage: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            if store.selected?.provider != .claude { DeskTabs(selection: $navigation.resetTab, items: [("earned", "Earned", "gift"), ("schedule", "Schedule", "clock")]) }
            if resetTab == "earned" && store.selected?.provider != .claude { EarnedView(earned: usage.rateLimitResetCredits) }
            else {
                ForEach(usage.meters.sorted { ($0.resetDate ?? .distantFuture) < ($1.resetDate ?? .distantFuture) }) { meter in
                    TimelineView(.periodic(from: .now, by: 30)) { context in
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(meter.label).font(.system(size: 12, weight: .medium))
                                Text(meter.bucket).font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                                Text(meter.resetDate.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? "Reset time not reported").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                            }
                            Spacer()
                            Text(countdown(meter.resetDate, now: context.date)).font(.system(size: 12, weight: .medium)).monospacedDigit()
                        }.deskCard()
                    }
                }
                if usage.meters.isEmpty { Text("No reset schedule reported.").font(.system(size: 12)).foregroundStyle(DeskTheme.muted) }
                Text("Times use your Mac’s time zone. An elapsed countdown awaits a usage update.").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Circle().fill(state.usage != nil && state.error == nil ? DeskTheme.status : state.error != nil ? DeskTheme.amber : DeskTheme.muted).frame(width: 5, height: 5).accessibilityHidden(true)
            Text(state.error != nil ? "Needs attention" : state.isLoading ? "Updating…" : state.usage != nil ? "Live" : "Not connected")
            if let date = state.updated { Text("·"); Text(date, style: .relative).help("Time since last successful read") }
            Spacer()
            Button { confirmingQuit = true } label: { Image(systemName: "power") }
                .buttonStyle(DeskIconButton()).help("Quit Usage desk").accessibilityLabel("Quit Usage desk")
        }.font(.system(size: 10)).foregroundStyle(DeskTheme.muted).padding(.horizontal, 20).padding(.vertical, 12)
    }
}

struct MeterView: View {
    let meter: UsageSnapshot.Meter
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(meter.label).font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
                Spacer(minLength: 2)
                Text(meter.bucket).font(.system(size: 9)).foregroundStyle(DeskTheme.muted).lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(Int(meter.remaining.rounded()))").foregroundStyle(meter.remaining <= 20 ? DeskTheme.quota(meter.remaining) : DeskTheme.text).font(.system(size: 37, weight: .regular)).tracking(-1).monospacedDigit()
                Text("% left").font(.system(size: 12)).foregroundStyle(DeskTheme.muted)
            }
            HStack(spacing: 3) {
                ForEach(0..<12) { index in
                    RoundedRectangle(cornerRadius: 2).fill(Double(index) / 12 < meter.remaining / 100 ? DeskTheme.quota(meter.remaining) : DeskTheme.track)
                }
            }.frame(height: 15).accessibilityElement(children: .ignore).accessibilityLabel("\(meter.label) remaining").accessibilityValue("\(Int(meter.remaining)) percent")
            TimelineView(.periodic(from: .now, by: 30)) { context in
                Text(meter.resetDate.map { $0 <= context.date ? "Awaiting update" : "Resets in \(countdown($0, now: context.date))" } ?? "Reset time not reported")
                    .font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                    .help(meter.resetDate.map { $0.formatted(date: .complete, time: .shortened) } ?? "Reset time not reported")
            }
        }.frame(maxWidth: .infinity, alignment: .leading).deskCard()
    }
}

struct EarnedView: View {
    let earned: UsageSnapshot.Earned?
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let earned {
                HStack {
                    Text("Earned resets").font(.system(size: 13, weight: .medium))
                    Spacer()
                    Text("\(earned.availableCount) available").font(.system(size: 12, weight: .medium)).monospacedDigit()
                }
                if let credits = earned.credits {
                    ForEach(credits) { credit in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(credit.title ?? "Earned usage reset").font(.system(size: 12, weight: .medium))
                            if let description = credit.description { Text(description).font(.system(size: 11)).foregroundStyle(DeskTheme.muted) }
                            Text(credit.expiry.map { "Expires \($0.formatted(date: .abbreviated, time: .shortened))" } ?? "No expiry reported").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                            Text(credit.status.capitalized).font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
                        }.frame(maxWidth: .infinity, alignment: .leading).deskCard()
                    }
                    if credits.count < earned.availableCount { Text("Some credit details were not returned. The available count above is authoritative.").font(.system(size: 10)).foregroundStyle(DeskTheme.muted) }
                    if credits.isEmpty { Text("No individual credit details returned.").font(.system(size: 11)).foregroundStyle(DeskTheme.muted) }
                } else { Text("Only the count was reported. Expiration dates are unavailable.").font(.system(size: 11)).foregroundStyle(DeskTheme.muted) }
                Text("Redeem in Codex.").font(.system(size: 10)).foregroundStyle(DeskTheme.muted)
            } else {
                Text("Earned resets not reported").font(.system(size: 13, weight: .medium))
                Text("Availability is unknown for this account.").font(.system(size: 11)).foregroundStyle(DeskTheme.muted)
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
