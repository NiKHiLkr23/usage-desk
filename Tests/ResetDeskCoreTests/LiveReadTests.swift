import XCTest
@testable import ResetDeskCore

final class LiveReadTests: XCTestCase {
    // Explicit opt-in: normal tests never read a real account or use network.
    func testSignedInCodexCanReadUsage() async throws {
        guard let path = ProcessInfo.processInfo.environment["RESET_DESK_LIVE_CODEX"] else { throw XCTSkip("Set RESET_DESK_LIVE_CODEX to opt into a read-only live check.") }
        let home = ProcessInfo.processInfo.environment["CODEX_HOME"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex")
        let client = CodexClient(executable: URL(fileURLWithPath: path), home: home)
        do {
            let account = try await client.call("account/read", as: AccountRead.self)
            XCTAssertEqual(account.account?.type, "chatgpt")
            let usage = try await client.call("account/rateLimits/read", as: UsageSnapshot.self)
            XCTAssertFalse(usage.meters.isEmpty, "Live account should return usage windows")
            await client.close()
        } catch { await client.close(); throw error }
    }
    func testSignedInClaudeCanReadUsageWithoutPrompt() async throws {
        guard let path = ProcessInfo.processInfo.environment["RESET_DESK_LIVE_CLAUDE"] else {
            throw XCTSkip("Set RESET_DESK_LIVE_CLAUDE to opt into a usage-only live check.")
        }
        let home = ProcessInfo.processInfo.environment["CLAUDE_CONFIG_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
        let client = ClaudeClient(executable: URL(fileURLWithPath: path), home: home)
        let read = try await client.read()
        XCTAssertNotNil(read.info, "Claude CLI must be signed in")
        XCTAssertFalse(read.usage?.meters.isEmpty ?? true, "Claude subscription must return usage windows")
    }

    func testTwoLiveProfilesCanPrepareAndCancelLogin() async throws {
        guard let path = ProcessInfo.processInfo.environment["RESET_DESK_LIVE_LOGIN"] else { throw XCTSkip("Set RESET_DESK_LIVE_LOGIN to test isolated login preparation without opening a browser.") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let firstHome = root.appendingPathComponent("first"), secondHome = root.appendingPathComponent("second")
        try FileManager.default.createDirectory(at: firstHome, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondHome, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = CodexClient(executable: URL(fileURLWithPath: path), home: firstHome, managed: true, timeoutSeconds: 10)
        let second = CodexClient(executable: URL(fileURLWithPath: path), home: secondHome, managed: true, timeoutSeconds: 10)
        do {
            let read = try await first.call("account/read", as: AccountRead.self)
            XCTAssertNil(read.account)
            let reply = try await second.call("account/login/start", params: ["type": "chatgpt"], as: BrowserLoginReply.self)
            XCTAssertNoThrow(try SignInURL.validated(reply.authUrl))
            XCTAssertFalse(reply.loginId.isEmpty)
            struct Empty: Decodable, Sendable {}
            _ = try await second.call("account/login/cancel", params: ["loginId": reply.loginId], as: Empty.self)
            // A new attempt must be able to acquire the callback listener too.
            let retry = try await second.call("account/login/start", params: ["type": "chatgpt"], as: BrowserLoginReply.self)
            XCTAssertNotEqual(reply.loginId, retry.loginId)
            _ = try await second.call("account/login/cancel", params: ["loginId": retry.loginId], as: Empty.self)
            await first.close(); await second.close()
        } catch { await first.close(); await second.close(); throw error }
    }

}
