import AppKit
import Combine
import ResetDeskCore
import ServiceManagement

struct AccountState {
    var info: AccountRead.Info?
    var workspaceID: String?
    var usage: UsageSnapshot?
    var updated: Date?
    var isLoading = false
    var error: String?
    var signedOut = false
    var unsupported = false
}

struct PendingLogin {
    var accountID: String
    var flow = BrowserLoginSession()
    var chromeProfile: String?
    var loginID: String? { flow.loginID }
    var url: URL? { flow.url }
}

@MainActor final class AccountStore: ObservableObject {
    let isDemo: Bool
    private let preferences: UserDefaults
    @Published var accounts: [LocalAccount] = []
    @Published var states: [String: AccountState] = [:]
    @Published var chromeProfiles: [ChromeProfile] = []
    @Published var selectedID: String { didSet { preferences.set(selectedID, forKey: "selectedAccount") } }
    @Published var pendingLogin: PendingLogin?
    @Published var message: String?
    @Published var launchAtLogin = SMAppService.mainApp.status == .enabled
    @Published var refreshInterval: Int { didSet { preferences.set(refreshInterval, forKey: "refreshInterval") } }
    @Published var showMenuPercent: Bool { didSet { preferences.set(showMenuPercent, forKey: "showMenuPercent") } }
    @Published var executablePath: String { didSet { preferences.set(executablePath, forKey: "codexExecutable") } }
    private let storage: AccountStorage
    private var storageWritable = true
    private var clients: [String: CodexClient] = [:]
    private var clientIDs: [String: UUID] = [:]
    private var refreshes: [String: Task<Void, Never>] = [:]
    private var polling: Task<Void, Never>?
    private var loginTimeout: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    var selected: LocalAccount? { accounts.first { $0.id == selectedID } ?? accounts.first }
    var selectedState: AccountState { states[selected?.id ?? ""] ?? AccountState() }
    var menuTitle: String {
        guard showMenuPercent else { return "" }
        let state = selectedState
        guard state.error == nil, let meter = state.usage?.meters.first else { return "—" }
        return "\(Int(meter.remaining.rounded()))%"
    }

    init(demo: Bool = ProcessInfo.processInfo.environment["USAGE_DESK_DEMO"] == "1" || Bundle.main.object(forInfoDictionaryKey: "UsageDeskDemo") as? Bool == true) {
        isDemo = demo
        let defaults = demo ? UserDefaults(suiteName: "in.nikhilkr.resetdesk.demo")! : UserDefaults.standard
        preferences = defaults
        selectedID = defaults.string(forKey: "selectedAccount") ?? "current"
        refreshInterval = [60, 120, 300].contains(defaults.integer(forKey: "refreshInterval")) ? defaults.integer(forKey: "refreshInterval") : 60
        showMenuPercent = defaults.object(forKey: "showMenuPercent") as? Bool ?? true
        executablePath = defaults.string(forKey: "codexExecutable") ?? Self.findCodex()
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = ProcessInfo.processInfo.environment["RESET_DESK_DATA_DIR"].map { URL(fileURLWithPath: $0) } ?? support.appendingPathComponent("ResetDesk", isDirectory: true)
        storage = AccountStorage(root: root)
        if demo {
            populateDemo()
            return
        }
        let cliHome = ProcessInfo.processInfo.environment["CODEX_HOME"] ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex").path
        accounts = [LocalAccount(id: "current", label: "Current Codex account", home: cliHome, managed: false)]
        do { accounts += try storage.load() }
        catch { storageWritable = false; message = "Saved account settings could not be read. They have not been overwritten. Check accounts.json in ResetDesk’s Application Support folder." }
        if !accounts.contains(where: { $0.id == selectedID }) { selectedID = "current" }
        reloadChromeProfiles()
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in await self?.refreshAll() }
        }
        polling = Task { [weak self] in
            await self?.refreshAll()
            while !Task.isCancelled {
                let interval = self?.refreshInterval ?? 60
                do { try await Task.sleep(for: .seconds(interval)) } catch { break }
                await self?.refreshAll()
            }
        }
    }

    static func findCodex() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = ["\(home)/.local/bin/codex", "/opt/homebrew/bin/codex", "/usr/local/bin/codex"]
            + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/codex" }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? "\(home)/.local/bin/codex"
    }

    func reloadChromeProfiles() {
        guard !isDemo else { return }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path = home.appendingPathComponent("Library/Application Support/Google/Chrome/Local State")
        // This reads only profile labels from Local State. No cookie, login,
        // password, history, or browser token databases are opened.
        chromeProfiles = (try? ChromeProfile.parse(localState: Data(contentsOf: path))) ?? []
    }

    private func client(for account: LocalAccount) throws -> CodexClient {
        guard !isDemo else { throw DeskError.message("Demo mode does not connect to Codex.") }
        if let client = clients[account.id] { return client }
        guard FileManager.default.isExecutableFile(atPath: executablePath) else { throw DeskError.message("Codex CLI was not found. Choose its executable in Settings.") }
        let clientID = UUID()
        clientIDs[account.id] = clientID
        let client = CodexClient(executable: URL(fileURLWithPath: executablePath), home: URL(fileURLWithPath: account.home), managed: account.managed) { [weak self] method, params in
            Task { @MainActor in self?.handleNotification(method, params: params, accountID: account.id, clientID: clientID) }
        }
        clients[account.id] = client
        return client
    }

    func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for account in accounts where pendingLogin?.accountID != account.id {
                group.addTask { await self.refresh(account.id) }
            }
        }
    }

    func refresh(_ id: String) async {
        guard !isDemo else { return }
        if let task = refreshes[id] { return await task.value }
        guard let account = accounts.first(where: { $0.id == id }), pendingLogin?.accountID != id else { return }
        let task = Task { @MainActor in
            var state = states[id] ?? AccountState()
            state.isLoading = true
            states[id] = state
            defer {
                states[id]?.isLoading = false
                refreshes[id] = nil
            }
            do {
                let client = try client(for: account)
                let read = try await client.call("account/read", as: AccountRead.self)
                guard accounts.contains(where: { $0.id == id }) else { return }
                var current = states[id] ?? AccountState()
                if current.info?.email != read.account?.email || current.workspaceID != read.workspaceRouting?.chatgptAccountId {
                    current.usage = nil; current.updated = nil
                }
                current.info = read.account; current.workspaceID = read.workspaceRouting?.chatgptAccountId
                current.error = nil; current.signedOut = read.account == nil
                current.unsupported = read.account != nil && read.account?.type != "chatgpt"
                states[id] = current
                guard read.account?.type == "chatgpt" else { states[id]?.usage = nil; return }
                let usage = try await client.call("account/rateLimits/read", as: UsageSnapshot.self)
                guard accounts.contains(where: { $0.id == id }) else { return }
                if let expected = current.workspaceID, let actual = usage.accountId, expected != actual { throw DeskError.message("The account changed during this read. Refresh again.") }
                states[id]?.usage = usage; states[id]?.updated = Date(); states[id]?.error = nil
            } catch { if accounts.contains(where: { $0.id == id }) { states[id]?.error = error.localizedDescription } }
        }
        refreshes[id] = task
        await task.value
    }

    func createAccount(label: String, chromeProfile: String?, expectedEmail: String?) throws -> String {
        guard !isDemo else { throw DeskError.message("Demo mode uses sample accounts. Open the regular app to connect your own.") }
        guard storageWritable else { throw DeskError.message("Repair saved account settings before adding an account.") }
        let label = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty, label.count <= 80 else { throw DeskError.message("Enter a label of up to 80 characters.") }
        guard accounts.count < 12 else { throw DeskError.message("You can track up to 12 profiles.") }
        let email = expectedEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = try storage.makeAccount(label: label, chromeProfile: chromeProfile, expectedEmail: email?.isEmpty == false ? email : nil)
        try storage.save(accounts + [account])
        accounts.append(account); selectedID = account.id; states[account.id] = AccountState(signedOut: true)
        return account.id
    }

    func beginSignIn(_ id: String, chromeProfile: String?) async throws {
        guard !isDemo else { throw DeskError.message("Demo mode cannot start sign-in.") }
        guard pendingLogin == nil else { throw DeskError.message("Finish or cancel the current sign-in first.") }
        guard let account = accounts.first(where: { $0.id == id }), account.managed else {
            throw DeskError.message("Sign in to the current CLI account using codex login in Terminal.")
        }
        // Reserve before suspension so two button presses cannot start callbacks.
        let login = PendingLogin(accountID: id, chromeProfile: chromeProfile)
        let attempt = login.flow.attemptID
        pendingLogin = login
        states[id]?.error = nil
        do {
            if let refresh = refreshes[id] { await refresh.value }
            guard pendingLogin?.flow.attemptID == attempt else { throw CancellationError() }
            // Retire the prior connection so delayed notifications cannot finish
            // a replacement sign-in, and an old callback cannot retain its port.
            clientIDs.removeValue(forKey: id)
            await clients.removeValue(forKey: id)?.close()
            guard pendingLogin?.flow.attemptID == attempt else { throw CancellationError() }
            states[id] = AccountState(signedOut: true)
            let client = try client(for: account)
            let reply = try await client.call("account/login/start", params: ["type": "chatgpt"], as: BrowserLoginReply.self)
            guard pendingLogin?.flow.attemptID == attempt else { throw CancellationError() }
            let earlyCompletion = try pendingLogin?.flow.ready(reply)
            if let index = accounts.firstIndex(where: { $0.id == id }) {
                accounts[index].chromeProfile = chromeProfile
                try storage.save(accounts)
            }
            if let earlyCompletion { finishSignIn(earlyCompletion, accountID: id); return }
            openPendingSignIn()
            loginTimeout?.cancel()
            loginTimeout = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(600)) } catch { return }
                guard self?.pendingLogin?.flow.attemptID == attempt else { return }
                await self?.cancelSignIn()
                self?.states[id]?.error = "Sign-in expired. Start again and use the newest browser tab."
            }
        } catch {
            guard pendingLogin?.flow.attemptID == attempt else { throw CancellationError() }
            pendingLogin = nil
            clientIDs.removeValue(forKey: id)
            await clients.removeValue(forKey: id)?.close()
            states[id]?.error = error.localizedDescription
            throw error
        }
    }

    func openPendingSignIn() {
        guard let login = pendingLogin, let url = login.url else { return }
        let attempt = login.flow.attemptID
        let failure: @Sendable () -> Void = { [weak self] in
            Task { @MainActor in
                guard self?.pendingLogin?.flow.attemptID == attempt else { return }
                self?.states[login.accountID]?.error = "Chrome could not open this profile. Copy the sign-in link or retry with the default browser."
            }
        }
        do { try BrowserLauncher.open(url, chromeProfile: login.chromeProfile, onFailure: failure) }
        catch { states[login.accountID]?.error = error.localizedDescription }
    }

    func cancelSignIn() async {
        guard let login = pendingLogin else { return }
        loginTimeout?.cancel(); loginTimeout = nil
        pendingLogin = nil
        // Closing works while the start request is still preparing, and releases
        // the callback listener immediately. No credentials are deleted.
        clientIDs.removeValue(forKey: login.accountID)
        await clients.removeValue(forKey: login.accountID)?.close()
        if let refresh = refreshes[login.accountID] { await refresh.value }
        states[login.accountID]?.error = nil
        await refresh(login.accountID)
    }

    private func handleNotification(_ method: String, params: Data, accountID: String, clientID: UUID) {
        guard clientIDs[accountID] == clientID else { return }
        if method == "usageDesk/connectionClosed", pendingLogin?.accountID == accountID {
            pendingLogin = nil; loginTimeout?.cancel(); loginTimeout = nil
            states[accountID]?.error = "Codex disconnected during sign-in. Start sign-in again."
            return
        }
        guard method == "account/login/completed", pendingLogin?.accountID == accountID,
              let completion = try? JSONDecoder().decode(BrowserLoginCompletion.self, from: params),
              let matched = pendingLogin?.flow.receive(completion) else { return }
        finishSignIn(matched, accountID: accountID)
    }

    private func finishSignIn(_ completion: BrowserLoginCompletion, accountID: String) {
        loginTimeout?.cancel(); loginTimeout = nil; pendingLogin = nil
        if completion.success {
            Task {
                await refresh(accountID)
                selectedID = accountID
                if let info = states[accountID]?.info, states[accountID]?.error == nil {
                    message = info.email.map { "Connected \($0)." } ?? "Account connected."
                } else if states[accountID]?.error == nil {
                    states[accountID]?.error = "Sign-in finished but no account was returned. Retry sign-in."
                }
            }
        } else { states[accountID]?.error = completion.failureMessage }
    }

    func removeAccount(_ id: String) async throws {
        guard !isDemo else { throw DeskError.message("Sample accounts cannot be removed in demo mode.") }
        guard id != "current", storageWritable else { return }
        if pendingLogin?.accountID == id { await cancelSignIn() }
        let remaining = accounts.filter { $0.id != id }
        try storage.save(remaining)
        accounts = remaining
        if selectedID == id { selectedID = "current" }
        clientIDs.removeValue(forKey: id)
        await clients.removeValue(forKey: id)?.close()
        states.removeValue(forKey: id)
        // Local credentials are retained. Removing a card never logs out or
        // deletes the user's Codex authentication.
    }

    func resetConnections() async {
        guard pendingLogin == nil else { message = "Finish sign-in before changing the CLI executable."; return }
        for client in clients.values { await client.close() }
        clients.removeAll(); clientIDs.removeAll()
        await refreshAll()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard !isDemo else { return }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLogin = SMAppService.mainApp.status == .enabled
            if enabled && !launchAtLogin { message = "Approve Usage desk in System Settings → General → Login Items." }
        } catch { launchAtLogin = SMAppService.mainApp.status == .enabled; message = "macOS could not change launch at login. Move the app to Applications and try again." }
    }

    func shutdown() {
        polling?.cancel(); loginTimeout?.cancel()
        for client in clients.values { Task { await client.close() } }
    }
}

@MainActor enum BrowserLauncher {
    static func open(_ url: URL, chromeProfile: String?, onFailure: @escaping @Sendable () -> Void) throws {
        guard let directory = chromeProfile else {
            guard NSWorkspace.shared.open(url) else { throw DeskError.message("Could not open the default browser. Copy the sign-in link instead.") }
            return
        }
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.google.Chrome") else { throw DeskError.message("Google Chrome was not found. Use the default browser or copy the link.") }
        let process = Process()
        process.executableURL = application.appendingPathComponent("Contents/MacOS/Google Chrome")
        process.arguments = ["--profile-directory=\(directory)", "--new-window", url.absoluteString]
        process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        process.terminationHandler = { process in if process.terminationStatus != 0 { onFailure() } }
        try process.run()
    }
}
