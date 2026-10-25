import Foundation

/// Claude CLI `get_usage`, not transcript tokens or API-equivalent spend.
public struct ClaudeUsageResponse: Decodable, Sendable {
    public struct Window: Decodable, Sendable {
        public var utilization: Double?
        public var resets_at: String?
    }
    public struct Limits: Decodable, Sendable {
        public var five_hour: Window?
        public var seven_day: Window?
    }
    public var subscription_type: String?
    public var rate_limits_available: Bool
    public var rate_limits: Limits?

    public func snapshot() throws -> UsageSnapshot? {
        guard rate_limits_available else { return nil }
        guard let rate_limits else { throw DeskError.message("Claude could not fetch current limits. Refresh to try again.") }
        func window(_ source: Window?, minutes: Int) -> UsageSnapshot.Window? {
            guard let source, let used = source.utilization, used.isFinite else { return nil }
            let date = source.resets_at.flatMap { value -> Date? in
                let parser = ISO8601DateFormatter()
                parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                return parser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
            }
            return UsageSnapshot.Window(usedPercent: min(100, max(0, used)), windowDurationMins: minutes, resetsAt: date?.timeIntervalSince1970)
        }
        let primary = window(rate_limits.five_hour, minutes: 300)
        let secondary = window(rate_limits.seven_day, minutes: 10080)
        // Unknown is never represented as a full allowance or zero resets.
        guard primary != nil || secondary != nil else { throw DeskError.message("Claude did not return any usage windows. Refresh after signing in with a Pro or Max account.") }
        return UsageSnapshot(rateLimits: .init(limitId: "claude", limitName: "Claude", primary: primary, secondary: secondary))
    }
}

public struct ClaudeRead: Sendable {
    public var info: AccountRead.Info?
    public var usage: UsageSnapshot?
}

/// Experimental Claude Code control protocol. Only initialize and get_usage are sent;
/// no user messages, prompts, tool permissions, or token/credential extraction.
public actor ClaudeClient {
    private struct Pending {
        var continuation: CheckedContinuation<Data, Error>
        var timeout: Task<Void, Never>
    }
    private let executable: URL
    private let home: URL
    private let arguments: [String]?
    private let timeoutSeconds: Double
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var reader: Task<Void, Never>?
    private var chunksContinuation: AsyncStream<Data>.Continuation?
    private var pending: [String: Pending] = [:]
    private var generation = UUID()
    private var workDirectory: URL?
    private var reading: Task<ClaudeRead, Error>?

    public init(executable: URL, home: URL, arguments: [String]? = nil, timeoutSeconds: Double = 45) {
        self.executable = executable; self.home = home; self.arguments = arguments; self.timeoutSeconds = timeoutSeconds
    }

    public func read() async throws -> ClaudeRead {
        if let reading { return try await reading.value }
        let task = Task { try await self.performRead() }
        reading = task
        defer { reading = nil }
        return try await task.value
    }

    private func performRead() async throws -> ClaudeRead {
        close()
        defer { close() }
        try start()
        struct Initialization: Decodable {
            struct Account: Decodable { var email: String?; var subscriptionType: String? }
            var account: Account?
        }
        let initialization = try JSONDecoder().decode(Initialization.self, from: await request("initialize"))
        let data = try await request("get_usage")
        let usage: ClaudeUsageResponse
        do { usage = try JSONDecoder().decode(ClaudeUsageResponse.self, from: data) }
        catch { throw DeskError.message("This Claude CLI response is not supported. Update Claude Code and Usage Desk.") }
        let account = initialization.account
        let info = account?.email == nil && usage.subscription_type == nil ? nil
            : AccountRead.Info(type: "claude", email: account?.email, planType: usage.subscription_type ?? account?.subscriptionType)
        return ClaudeRead(info: info, usage: try usage.snapshot())
    }

    private func start() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("usage-desk-claude-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        workDirectory = directory
        let proc = Process(), stdin = Pipe(), stdout = Pipe()
        proc.executableURL = executable
        proc.arguments = arguments ?? ["-p", "--input-format", "stream-json", "--output-format", "stream-json", "--verbose",
            "--no-session-persistence", "--tools", "", "--permission-mode", "plan", "--disable-slash-commands",
            "--setting-sources", "", "--strict-mcp-config", "--mcp-config", "{\"mcpServers\":{}}",
            "--settings", "{\"disableAllHooks\":true,\"autoMemoryEnabled\":false}"]
        // Never inherit API keys, alternate endpoints, or a shell-scoped provider.
        let source = ProcessInfo.processInfo.environment
        var env = [String: String]()
        for key in ["HOME", "PATH", "TMPDIR", "LANG", "LC_ALL"] { env[key] = source[key] }
        env["PATH"] = executable.deletingLastPathComponent().path + ":" + (source["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        // Claude uses USER to resolve its macOS Keychain account. GUI launches
        // may omit it; use the current OS user without inheriting credential variables.
        env["USER"] = NSUserName()
        env["CLAUDE_CONFIG_DIR"] = home.path
        // The umbrella traffic flag also suppresses quota reads in Claude Code.
        // Disable optional reporting and updates explicitly while allowing get_usage.
        for key in ["DISABLE_TELEMETRY", "DISABLE_ERROR_REPORTING", "DISABLE_AUTOUPDATER", "DISABLE_FEEDBACK_COMMAND"] { env[key] = "1" }
        proc.environment = env
        proc.currentDirectoryURL = directory
        proc.standardInput = stdin; proc.standardOutput = stdout; proc.standardError = FileHandle.nullDevice
        try proc.run()
        process = proc; input = stdin.fileHandleForWriting; output = stdout.fileHandleForReading
        let connection = UUID(); generation = connection
        let (chunks, continuation) = AsyncStream<Data>.makeStream()
        chunksContinuation = continuation
        output?.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; continuation.finish() }
            else { continuation.yield(data) }
        }
        reader = Task { [weak self] in
            var buffer = Data()
            for await chunk in chunks {
                if Task.isCancelled { break }
                buffer.append(chunk)
                guard buffer.count < 2_000_000 else { await self?.close(); return }
                while let end = buffer.firstIndex(of: 10) {
                    let line = Data(buffer[..<end]); buffer.removeSubrange(...end)
                    await self?.receive(line, connection: connection)
                }
            }
            await self?.disconnected(connection: connection)
        }
    }

    private func request(_ method: String) async throws -> Data {
        guard ["initialize", "get_usage"].contains(method) else { throw DeskError.message("Only Claude usage reads are supported.") }
        let id = UUID().uuidString
        return try await withCheckedThrowingContinuation { continuation in
            let timeout = Task { [weak self, timeoutSeconds] in
                do { try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000)) } catch { return }
                await self?.expire(id)
            }
            pending[id] = Pending(continuation: continuation, timeout: timeout)
            var request: [String: Any] = ["subtype": method]
            if method == "get_usage" { request["skip_behaviors"] = true }
            do {
                var data = try JSONSerialization.data(withJSONObject: ["type": "control_request", "request_id": id, "request": request])
                data.append(10)
                guard let input else { throw DeskError.message("Claude is disconnected.") }
                try input.write(contentsOf: data)
            } catch { close() }
        }
    }

    private func receive(_ line: Data, connection: UUID) {
        guard connection == generation, let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else { return }
        // Reject any request from the CLI. Usage Desk grants no tools or permissions.
        if object["type"] as? String == "control_request" {
            guard let id = object["request_id"] as? String, let input else { return }
            if var data = try? JSONSerialization.data(withJSONObject: ["type": "control_response", "response": ["subtype": "error", "request_id": id, "error": "Usage Desk supports read-only usage requests."]]) {
                data.append(10); try? input.write(contentsOf: data)
            }
            return
        }
        guard object["type"] as? String == "control_response", let response = object["response"] as? [String: Any],
              let id = response["request_id"] as? String, let waiting = pending.removeValue(forKey: id) else { return }
        waiting.timeout.cancel()
        guard response["subtype"] as? String == "success", let value = response["response"],
              let data = try? JSONSerialization.data(withJSONObject: value) else {
            waiting.continuation.resume(throwing: DeskError.message("Claude could not read subscription usage. Check your CLI sign-in or update Claude Code.")); return
        }
        waiting.continuation.resume(returning: data)
    }

    private func expire(_ id: String) {
        guard let item = pending.removeValue(forKey: id) else { return }
        item.timeout.cancel()
        item.continuation.resume(throwing: DeskError.message("Claude took too long to respond. Check your connection and try Refresh."))
        close()
    }
    private func disconnected(connection: UUID) {
        guard connection == generation else { return }
        close()
    }
    public func close() {
        generation = UUID()
        output?.readabilityHandler = nil; output = nil
        chunksContinuation?.finish(); chunksContinuation = nil
        reader?.cancel(); reader = nil
        try? input?.close(); input = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        for item in pending.values { item.timeout.cancel(); item.continuation.resume(throwing: DeskError.message("Claude disconnected. Check its CLI sign-in and refresh.")) }
        pending.removeAll()
        if let directory = workDirectory { try? FileManager.default.removeItem(at: directory) }
        workDirectory = nil
    }
}
