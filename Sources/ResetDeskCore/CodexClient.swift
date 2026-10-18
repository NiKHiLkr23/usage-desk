import Foundation

public actor CodexClient {
    private struct Pending {
        var continuation: CheckedContinuation<Data, Error>
        var timeout: Task<Void, Never>
    }
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var chunksContinuation: AsyncStream<Data>.Continuation?
    private var reader: Task<Void, Never>?
    private var pending: [Int: Pending] = [:]
    private var sequence = 0
    private var initialized = false
    private var connecting: Task<Void, Error>?
    private let executable: URL
    private let arguments: [String]
    private let home: URL
    private let notification: @Sendable (String, Data) -> Void
    private let timeoutSeconds: Double
    private var generation = UUID()

    public init(executable: URL, home: URL, managed: Bool = false, arguments: [String]? = nil, timeoutSeconds: Double = 30, notification: @escaping @Sendable (String, Data) -> Void = { _, _ in }) {
        self.executable = executable; self.home = home; self.notification = notification
        self.arguments = arguments ?? (["app-server", "--listen", "stdio://"] + (managed ? ["-c", "cli_auth_credentials_store=\"file\""] : []))
        self.timeoutSeconds = timeoutSeconds
    }

    public func connect() async throws {
        if initialized { return }
        if let connecting { return try await connecting.value }
        let task = Task { try await self.start() }
        connecting = task
        defer { connecting = nil }
        try await task.value
    }

    private func start() async throws {
        let proc = Process()
        let stdout = Pipe(), stdin = Pipe()
        proc.executableURL = executable
        proc.arguments = arguments
        // Isolate profile auth from shell-scoped account/provider overrides.
        var env = ProcessInfo.processInfo.environment
        for key in ["OPENAI_API_KEY", "CODEX_ACCESS_TOKEN", "OPENAI_IDENTITY_TOKEN_FILE", "CODEX_SQLITE_HOME"] { env.removeValue(forKey: key) }
        env["CODEX_HOME"] = home.path
        proc.environment = env
        proc.currentDirectoryURL = home
        proc.standardInput = stdin
        proc.standardOutput = stdout
        proc.standardError = FileHandle.nullDevice
        let connection = UUID()
        generation = connection
        do { try proc.run() } catch { throw DeskError.message("Could not launch Codex CLI. Check its location in Settings.") }
        process = proc; input = stdin.fileHandleForWriting
        // FileHandle.bytes uses a shared blocking reader on macOS. An idle
        // profile can starve every other profile's stdout (including login).
        // Read only ready bytes and serialize chunks through a per-client stream.
        let (chunks, continuation) = AsyncStream<Data>.makeStream()
        output = stdout.fileHandleForReading
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
                while let end = buffer.firstIndex(of: 10) {
                    let line = String(decoding: buffer[..<end], as: UTF8.self)
                    buffer.removeSubrange(...end)
                    await self?.receive(line, connection: connection)
                }
            }
            await self?.disconnected(connection: connection)
        }
        do {
            let _: Data = try await request("initialize", params: ["clientInfo": ["name": "usage_desk_macos", "title": "Usage desk", "version": "0.1.0"]])
            try send(["method": "initialized", "params": [:]])
            initialized = true
        } catch { close(); throw error }
    }

    public func call<T: Decodable & Sendable>(_ method: String, params: [String: String]? = nil, as type: T.Type) async throws -> T {
        guard ["account/read", "account/rateLimits/read", "account/login/start", "account/login/cancel"].contains(method) else { throw DeskError.message("This is a read-only usage app. That operation is unavailable.") }
        try await connect()
        // account/read requires a params object even when no options are set.
        let data = try await request(method, params: params ?? [:])
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw DeskError.message("Codex returned a response this version cannot read. Update Codex or Usage desk.") }
    }

    private func request(_ method: String, params: Any? = nil) async throws -> Data {
        sequence += 1
        let id = sequence
        return try await withCheckedThrowingContinuation { continuation in
            let timer = Task { [weak self, timeoutSeconds] in
                do { try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000)) } catch { return }
                await self?.expire(id)
            }
            pending[id] = Pending(continuation: continuation, timeout: timer)
            do {
                var object: [String: Any] = ["id": id, "method": method]
                if let params { object["params"] = params }
                try send(object)
            } catch {
                pending.removeValue(forKey: id)?.timeout.cancel()
                continuation.resume(throwing: DeskError.message("Lost connection to Codex. Refresh to reconnect."))
            }
        }
    }

    private func send(_ object: [String: Any]) throws {
        guard let input else { throw DeskError.message("Codex is not connected.") }
        var data = try JSONSerialization.data(withJSONObject: object)
        data.append(10)
        try input.write(contentsOf: data)
    }

    private func receive(_ line: String, connection: UUID) {
        guard connection == generation, let bytes = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { return }
        if let id = object["id"] as? Int, let request = pending.removeValue(forKey: id) {
            request.timeout.cancel()
            if let error = object["error"] as? [String: Any] {
                let code = error["code"] as? Int
                let message = error["message"] as? String ?? ""
                let lower = message.lowercased()
                let text: String
                if code == -32601 || lower.contains("unknown variant") { text = "This Codex CLI does not support usage reads. Update Codex and restart Usage desk." }
                else if lower.contains("401") || lower.contains("unauthorized") || lower.contains("refresh token") { text = "This account needs to sign in again. Use Reconnect." }
                else if lower.contains("address already in use") || lower.contains("1455") { text = "Another Codex sign-in is using the callback port. Finish or cancel it, then retry." }
                else { text = "Codex could not complete the request. Check your connection and sign-in, then retry." }
                request.continuation.resume(throwing: DeskError.message(text))
            } else if let result = object["result"], let resultData = try? JSONSerialization.data(withJSONObject: result, options: [.fragmentsAllowed]) {
                request.continuation.resume(returning: resultData)
            } else { request.continuation.resume(throwing: DeskError.message("Codex returned an empty response.")) }
        } else if let method = object["method"] as? String {
            if object["id"] != nil {
                try? send(["id": object["id"]!, "error": ["code": -32601, "message": "Unsupported by read-only Usage desk"]])
            } else {
                let params = (try? JSONSerialization.data(withJSONObject: object["params"] ?? [:], options: [.fragmentsAllowed])) ?? Data()
                notification(method, params)
            }
        }
    }

    private func expire(_ id: Int) {
        guard let request = pending.removeValue(forKey: id) else { return }
        request.continuation.resume(throwing: DeskError.message("Codex took too long to respond. Check your connection and retry."))
        // A timed-out login must not retain an invisible callback server.
        close()
    }

    private func disconnected(connection: UUID) {
        guard connection == generation else { return }
        initialized = false; input = nil
        output?.readabilityHandler = nil; output = nil
        chunksContinuation?.finish(); chunksContinuation = nil
        notification("usageDesk/connectionClosed", Data())
        for item in pending.values { item.timeout.cancel(); item.continuation.resume(throwing: DeskError.message("Codex disconnected. Refresh to reconnect.")) }
        pending.removeAll()
    }

    public func close() {
        generation = UUID(); initialized = false
        output?.readabilityHandler = nil
        chunksContinuation?.finish(); chunksContinuation = nil
        reader?.cancel(); reader = nil
        try? output?.close(); output = nil
        try? input?.close(); input = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        for item in pending.values { item.timeout.cancel(); item.continuation.resume(throwing: DeskError.message("Codex connection closed.")) }
        pending.removeAll()
    }
}
