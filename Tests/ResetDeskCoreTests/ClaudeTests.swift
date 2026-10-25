import XCTest
@testable import ResetDeskCore

final class ClaudeTests: XCTestCase {
    private func decode(_ json: String) throws -> ClaudeUsageResponse {
        try JSONDecoder().decode(ClaudeUsageResponse.self, from: Data(json.utf8))
    }
    func testLegacyAccountsDefaultToCodexAndRoundTripProvider() throws {
        let legacy = Data(#"[{"id":"saved","label":"Work","home":"/synthetic/work","managed":true}]"#.utf8)
        let accounts = try JSONDecoder().decode([LocalAccount].self, from: legacy)
        XCTAssertEqual(accounts[0].provider, .codex)
        var claude = accounts[0]; claude.provider = .claude
        XCTAssertEqual(try JSONDecoder().decode(LocalAccount.self, from: JSONEncoder().encode(claude)).provider, .claude)
    }
    func testUnknownProviderIsRejectedRatherThanRelabeled() {
        XCTAssertThrowsError(try JSONDecoder().decode(LocalAccount.self, from: Data(#"{"id":"x","label":"x","home":"/synthetic","managed":true,"provider":"future"}"#.utf8)))
    }
    func testClaudeMapsPercentagesAndISOResetTimesWithoutEarnedCredits() throws {
        let response = try decode(#"{"subscription_type":"pro","rate_limits_available":true,"rate_limits":{"five_hour":{"utilization":25.5,"resets_at":"2099-01-01T12:00:00Z"},"seven_day":{"utilization":70,"resets_at":"2099-01-05T12:00:00.000Z"}}}"#)
        let usage = try XCTUnwrap(response.snapshot())
        XCTAssertEqual(usage.meters.map(\.remaining), [74.5,30])
        XCTAssertEqual(usage.meters.map(\.bucket), ["Claude","Claude"])
        XCTAssertEqual(usage.meters.map(\.label), ["5-hour window","Weekly window"])
        XCTAssertNotNil(usage.meters.first?.resetDate)
        XCTAssertNotNil(usage.meters.last?.resetDate)
        XCTAssertNil(usage.rateLimitResetCredits)
    }
    func testUnknownLimitsDoNotBecomeFullQuota() throws {
        XCTAssertNil(try decode(#"{"rate_limits_available":false,"rate_limits":null}"#).snapshot())
        XCTAssertThrowsError(try decode(#"{"rate_limits_available":true,"rate_limits":null}"#).snapshot())
        XCTAssertThrowsError(try decode(#"{"rate_limits_available":true,"rate_limits":{}}"#).snapshot())
    }
    func testPartialWindowsClampedAndBadDatesRemainUnknown() throws {
        let usage = try XCTUnwrap(decode(#"{"rate_limits_available":true,"rate_limits":{"seven_day":{"utilization":120,"resets_at":"bad"}}}"#).snapshot())
        XCTAssertEqual(usage.meters.count, 1)
        XCTAssertEqual(usage.meters[0].remaining, 0)
        XCTAssertNil(usage.meters[0].resetDate)
    }
    private func client(_ mode: String = "success", timeout: Double = 2) throws -> ClaudeClient {
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "fake-claude", withExtension: "py", subdirectory: "Fixtures"))
        return ClaudeClient(executable: URL(fileURLWithPath: "/usr/bin/python3"), home: URL(fileURLWithPath: "/synthetic/claude"), arguments: [fixture.path,mode], timeoutSeconds: timeout)
    }
    func testUsageOnlyHandshakeAndRepeatReads() async throws {
        let client = try client()
        let read = try await client.read()
        XCTAssertEqual(read.info?.email, "fixture@example.test")
        XCTAssertEqual(read.info?.planType, "pro")
        XCTAssertEqual(read.usage?.meters.first?.remaining, 75)
        let second = try await client.read()
        XCTAssertEqual(second.info?.email, read.info?.email)
    }
    func testConcurrentReadsShareOneProbe() async throws {
        let client = try client()
        async let first = client.read()
        async let second = client.read()
        let (a,b) = try await (first,second)
        XCTAssertEqual(a.info?.email,b.info?.email)
        XCTAssertEqual(a.usage?.meters.first?.remaining,b.usage?.meters.first?.remaining)
    }
    func testProductionArgumentsDisableToolsHooksAndTranscriptPersistence() async throws {
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "fake-claude", withExtension: "py", subdirectory: "Fixtures"))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appendingPathComponent("claude")
        let source = try String(contentsOf: fixture, encoding: .utf8)
        try ("#!/usr/bin/python3\n" + source).write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: executable.path)
        let client = ClaudeClient(executable: executable, home: directory)
        let read = try await client.read()
        XCTAssertEqual(read.usage?.meters.first?.remaining, 75)
    }

    func testUnavailableDoesNotReportSuccessfulUsage() async throws {
        let client = try client("null")
        do { _ = try await client.read(); XCTFail("Null limits are unavailable") } catch { XCTAssertTrue(error.localizedDescription.contains("current limits")) }
        let api = try self.client("unsupported")
        let read = try await api.read()
        XCTAssertNil(read.usage)
    }
    func testMalformedAndBackendFailuresAreSanitized() async throws {
        for mode in ["error","malformed","exit"] {
            let client = try client(mode)
            do { _ = try await client.read(); XCTFail("Expected \(mode) failure") }
            catch { XCTAssertFalse(error.localizedDescription.contains("private-token")) }
        }
    }
    func testTimeoutAndCloseCompletePendingReads() async throws {
        let client = try client("hang", timeout: 0.2)
        do { _ = try await client.read(); XCTFail("Expected timeout") }
        catch { XCTAssertTrue(error.localizedDescription.contains("too long")) }
        let cancellable = try self.client("hang")
        let task = Task { try await cancellable.read() }
        try await Task.sleep(nanoseconds: 80_000_000)
        await cancellable.close()
        do { _ = try await task.value; XCTFail("Close must cancel pending read") } catch { }
    }
}
