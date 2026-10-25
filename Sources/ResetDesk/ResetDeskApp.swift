import SwiftUI
import AppKit
import Combine
import ResetDeskCore

@main struct ResetDeskApp: App {
    @StateObject private var store: AccountStore
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    init() {
        let model = AccountStore()
        _store = StateObject(wrappedValue: model)
        AppDelegate.startupStore = model
    }
    var body: some Scene {
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Preferences…") { AppWindows.showSettings(store) }.keyboardShortcut(",")
                }
                CommandMenu("Navigate") {
                    Button("Usage") { AppWindows.showTab(store, tab: "usage") }.keyboardShortcut("1")
                    Button("Resets") { AppWindows.showTab(store, tab: "resets") }.keyboardShortcut("2")
                    Button("Accounts") { AppWindows.showTab(store, tab: "accounts") }.keyboardShortcut("3")
                }
            }
    }
}

@MainActor final class DeskNavigation: ObservableObject {
    enum Page { case usage, accounts, preferences }
    @Published var page: Page = .usage
    @Published var accountSelection: String?
    @Published var usageTab = "usage"
    @Published var resetTab = "earned"
    @Published var accountScrollID: String?
    @Published var executableDraft: String?
    @Published var claudeExecutableDraft: String?
    private var accountDrafts: [String: AccountFormDraft] = [:]
    func draft(for account: LocalAccount?) -> AccountFormDraft {
        let key = account?.id ?? "new"
        if let draft = accountDrafts[key] { return draft }
        let draft = AccountFormDraft(account: account)
        accountDrafts[key] = draft
        return draft
    }
    func createdAccount(_ id: String) {
        accountDrafts[id] = accountDrafts.removeValue(forKey: "new")
        accountSelection = id
    }
    func manageAccounts(selectedID: String?) {
        accountSelection = selectedID
        page = .accounts
    }
    func addAccount(provider: AccountProvider) {
        draft(for: nil).provider = provider
        manageAccounts(selectedID: nil)
    }
    func showTab(_ tab: String) { usageTab = tab; page = .usage }
    func showUsage() { showTab("usage") }
    private var returnPage: Page = .usage
    func showPreferences() { if page != .preferences { returnPage = page }; page = .preferences }
    func back() { page = page == .preferences ? returnPage : .usage }
    var size: NSSize { page == .accounts ? NSSize(width: 660, height: 600) : NSSize(width: 420, height: 500) }
}

struct DeskRootView: View {
    @ObservedObject var store: AccountStore
    @ObservedObject var navigation: DeskNavigation
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                if navigation.page != .usage {
                    Button { navigation.back() } label: { Image(systemName: "chevron.left") }
                        .buttonStyle(DeskIconButton()).help("Back").accessibilityLabel("Back")
                }
                Text(navigation.page == .accounts ? "Accounts" : navigation.page == .preferences ? "Preferences" : "usage desk").font(.system(size: 17, weight: .semibold)).tracking(-0.4)
                if store.isDemo { Text("Demo").font(.system(size: 9, weight: .medium)).foregroundStyle(DeskTheme.muted) }
                Spacer()
                if navigation.page == .usage {
                    Button { Task { await store.refresh(store.selected?.id ?? "current") } } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(DeskIconButton()).disabled(store.selectedState.isLoading).help("Refresh usage").accessibilityLabel("Refresh usage")
                }
                Button { navigation.showPreferences() } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(DeskIconButton()).help("Preferences").accessibilityLabel("Preferences")
                    .disabled(navigation.page == .preferences)
                AppearanceButton()
            }.padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 12)
            if navigation.page == .usage {
                DashboardView(store: store, navigation: navigation)
            } else if navigation.page == .preferences {
                ScrollView { SettingsView(store: store, navigation: navigation).padding(.horizontal, 20).padding(.bottom, 24) }
            } else {
                AccountManagerView(store: store, navigation: navigation)
            }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(DeskTheme.background).foregroundStyle(DeskTheme.text).tint(DeskTheme.text).deskAppearance()
            .onChange(of: store.connectionCompleted) { _, connection in
                guard connection != nil else { return }
                navigation.showUsage()
            }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var startupStore: AccountStore?
    private var statusItem: NSStatusItem?
    private var observation: AnyCancellable?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        guard let store = Self.startupStore else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.title = store.menuTitle.isEmpty ? "usage desk" : store.menuTitle
        item.button?.toolTip = "Usage desk"
        item.button?.target = self
        item.button?.action = #selector(toggleDesk)
        AppWindows.anchor = item.button
        observation = store.objectWillChange.receive(on: RunLoop.main).sink { [weak self, weak store] in
            guard let store else { return }
            self?.statusItem?.button?.title = store.menuTitle.isEmpty ? "usage desk" : store.menuTitle
        }
        if !UserDefaults.standard.bool(forKey: "finishedFirstLaunch") {
            AppWindows.showDashboard(store)
            UserDefaults.standard.set(true, forKey: "finishedFirstLaunch")
        }
    }
    @objc private func toggleDesk() {
        guard let store = Self.startupStore else { return }
        if AppWindows.isShown { AppWindows.hide() }
        else { AppWindows.show(store) }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if let store = Self.startupStore { AppWindows.show(store) }
        return true
    }
    func applicationWillTerminate(_ notification: Notification) { Self.startupStore?.shutdown() }
}

/// Presentation can disappear independently of navigation, form drafts, and the
/// AccountStore-owned browser login. Reopening never creates another login attempt.
@MainActor enum AppWindows {
    static weak var anchor: NSStatusBarButton?
    private static let navigation = DeskNavigation()
    private static var popover: NSPopover?
    private static var routeObservation: AnyCancellable?
    private static let resizeAnimator = PanelResizeAnimator()
    private static let lifecycle = DeskPopoverLifecycle()
    static var isShown: Bool { popover?.isShown == true }
    static func hide() { popover?.performClose(nil) }
    static func stopResize() { resizeAnimator.cancel() }

    static func show(_ store: AccountStore) {
        guard let anchor, anchor.window != nil else { return }
        if popover == nil {
            let panel = NSPopover()
            panel.behavior = .transient
            panel.delegate = lifecycle
            let host = DeskHostingController(rootView: DeskRootView(store: store, navigation: navigation))
            host.sizingOptions = []
            panel.contentViewController = host
            popover = panel
            routeObservation = navigation.$page.dropFirst().receive(on: RunLoop.main).sink { _ in resize() }
        }
        guard let popover else { return }
        resize()
        guard !popover.isShown else { return }
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        // Cached values render immediately; refresh continues without blocking entry.
        Task { await store.refresh(store.selected?.id ?? "current") }
    }
    static func showDashboard(_ store: AccountStore) { navigation.showUsage(); show(store) }
    static func showAccounts(_ store: AccountStore, selectedID: String? = nil) {
        navigation.manageAccounts(selectedID: selectedID)
        show(store)
    }
    static func showTab(_ store: AccountStore, tab: String) { navigation.showTab(tab); show(store) }
    static func addAccount(_ store: AccountStore, provider: AccountProvider) { navigation.addAccount(provider: provider); show(store) }
    static func showSettings(_ store: AccountStore) { navigation.showPreferences(); show(store) }

    private static func resize() {
        guard let popover else { return }
        let desired = navigation.size
        let visible = anchor?.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
        let size = NSSize(width: min(desired.width, max(1, (visible?.width ?? desired.width) - 24)),
                          height: min(desired.height, max(1, (visible?.height ?? desired.height) - 24)))
        let shouldAnimate = popover.isShown && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        // NSPopover.animates is only a system hint. Drive actual content sizes over
        // time, with one owner for sizing; a fixed SwiftUI frame would jump ahead.
        resizeAnimator.resize(from: popover.contentSize, to: size, animated: shouldAnimate) { [weak popover] frameSize in
            guard let popover else { return }
            let wasAnimated = popover.animates
            popover.animates = false
            popover.contentSize = frameSize
            popover.contentViewController?.view.layoutSubtreeIfNeeded()
            popover.animates = wasAnimated
        }
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
}

@MainActor private final class DeskPopoverLifecycle: NSObject, NSPopoverDelegate {
    func popoverWillClose(_ notification: Notification) { AppWindows.stopResize() }
}

@MainActor private final class DeskHostingController: NSHostingController<DeskRootView> {
    private var keyMonitor: Any?
    override func viewDidAppear() {
        super.viewDidAppear()
        guard keyMonitor == nil else { return }
        // Menu-bar apps have no persistent main window. Route shortcuts only while
        // this popover owns the key event, leaving browser and terminal typing alone.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.view.window,
                  event.modifierFlags.intersection([.command, .control, .option, .shift]) == .command else { return event }
            switch event.charactersIgnoringModifiers {
            case "1": self.rootView.navigation.showTab("usage")
            case "2": self.rootView.navigation.showTab("resets")
            case "3": self.rootView.navigation.showTab("accounts")
            case ",": self.rootView.navigation.showPreferences()
            default: return event
            }
            return nil
        }
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
    override func cancelOperation(_ sender: Any?) { AppWindows.hide() }
}

@MainActor final class AccountFormDraft: ObservableObject {
    @Published var provider: AccountProvider
    @Published var claudeHome: String
    @Published var label: String
    @Published var chrome: String
    @Published var email: String
    init(account: LocalAccount?) {
        provider = account?.provider ?? .codex
        claudeHome = account?.home ?? (ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude").path)
        label = account?.label ?? ""
        chrome = account?.chromeProfile ?? "default-browser"
        email = account?.expectedEmail ?? ""
    }
}
