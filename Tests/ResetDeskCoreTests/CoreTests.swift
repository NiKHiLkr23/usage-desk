import XCTest
@testable import ResetDeskCore

final class CoreTests: XCTestCase {
    func usage(_ json: String) throws -> UsageSnapshot { try JSONDecoder().decode(UsageSnapshot.self, from: Data(json.utf8)) }

    func testUnknownEarnedCountIsDifferentFromZero() throws {
        let unknown = try usage(#"{"rateLimits":{},"rateLimitResetCredits":null}"#)
        XCTAssertNil(unknown.rateLimitResetCredits)
        let zero = try usage(#"{"rateLimits":{},"rateLimitResetCredits":{"availableCount":0,"credits":[]}}"#)
        XCTAssertEqual(zero.rateLimitResetCredits?.availableCount, 0)
        XCTAssertEqual(zero.rateLimitResetCredits?.credits?.count, 0)
    }

    func testMultiBucketMappingAvoidsDuplicatingLegacyBucket() throws {
        let snapshot = try usage(#"{"rateLimits":{"primary":{"usedPercent":99}},"rateLimitsByLimitId":{"codex":{"primary":{"usedPercent":30,"windowDurationMins":300,"resetsAt":1900000000},"secondary":{"usedPercent":82,"windowDurationMins":10080}},"other":{"limitName":"Other model","primary":{"usedPercent":0,"resetsAt":null}}}}"#)
        XCTAssertEqual(snapshot.meters.count, 3)
        XCTAssertEqual(snapshot.meters[0].remaining, 70)
        XCTAssertEqual(snapshot.meters[0].resetDate?.timeIntervalSince1970, 1900000000)
        XCTAssertEqual(snapshot.meters[1].label, "Weekly window")
        XCTAssertNil(snapshot.meters[1].resetDate)
        XCTAssertEqual(snapshot.meters[2].bucket, "Other model")
    }

    func testCountDoesNotDependOnDetailRows() throws {
        let snapshot = try usage(#"{"rateLimits":{},"rateLimitResetCredits":{"availableCount":7,"credits":[{"id":"one","status":"available","resetType":"codexRateLimits","grantedAt":1800000000,"expiresAt":null}]}}"#)
        XCTAssertEqual(snapshot.rateLimitResetCredits?.availableCount, 7)
        XCTAssertEqual(snapshot.rateLimitResetCredits?.credits?.count, 1)
        XCTAssertNil(snapshot.rateLimitResetCredits?.credits?.first?.expiry)
    }

    func testClampsPercentagesWithoutInferringQuotaRecovery() throws {
        let snapshot = try usage(#"{"rateLimits":{"primary":{"usedPercent":130,"resetsAt":1},"secondary":{"usedPercent":-5}}}"#)
        XCTAssertEqual(snapshot.meters[0].remaining, 0)
        XCTAssertEqual(snapshot.meters[0].resetDate, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(snapshot.meters[1].remaining, 100)
    }

    func testSignInAddressesAreValidated() throws {
        for url in ["https://auth.openai.com/authorize?state=test", "https://chatgpt.com/oauth/authorize", "https://auth.chatgpt.com/authorize"] {
            XCTAssertNoThrow(try SignInURL.validated(url))
        }
        for url in ["http://auth.openai.com/authorize", "https://auth.openai.com.attacker.test/", "https://user@auth.openai.com/", "https://auth.openai.com:9999/", "file:///tmp/auth"] {
            XCTAssertThrowsError(try SignInURL.validated(url))
        }
    }

    func testChromeProfileMetadataAndUnsafePaths() throws {
        let localState = Data(#"{"profile":{"info_cache":{"Default":{"name":"Personal","user_name":"first@example.test"},"Profile 2":{"name":"Work","user_name":"second@example.test"},"../escape":{"name":"Invalid"}}}}"#.utf8)
        let profiles = try ChromeProfile.parse(localState: localState)
        XCTAssertEqual(profiles.count, 2)
        XCTAssertEqual(profiles.first?.email, "first@example.test")
        XCTAssertTrue(profiles.last?.displayName.contains("second@example.test") == true)
    }

    func testAccountsPersistWithSeparateHomesAndPrivatePermissions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = AccountStorage(root: root)
        let first = try storage.makeAccount(label: "Personal", chromeProfile: "Default", expectedEmail: "one@example.test")
        let second = try storage.makeAccount(label: "Work", chromeProfile: nil, expectedEmail: "two@example.test", provider: .claude)
        XCTAssertNotEqual(first.home, second.home)
        try storage.save([first, second])
        XCTAssertEqual(try storage.load(), [first, second])
        let attrs = try FileManager.default.attributesOfItem(atPath: root.appendingPathComponent("accounts.json").path)
        XCTAssertEqual((attrs[.posixPermissions] as? NSNumber)?.intValue, 0o600)
        try storage.save([second])
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.home), "Removing metadata must not erase authentication directories")
    }


    func testLoginCompletionBeforeReplyIsMatchedByLoginID() throws {
        var flow = BrowserLoginSession()
        let old = try JSONDecoder().decode(BrowserLoginCompletion.self, from: Data(#"{"loginId":"old","success":false}"#.utf8))
        let correct = try JSONDecoder().decode(BrowserLoginCompletion.self, from: Data(#"{"loginId":"new","success":true}"#.utf8))
        XCTAssertNil(flow.receive(old))
        XCTAssertNil(flow.receive(correct))
        let reply = try JSONDecoder().decode(BrowserLoginReply.self, from: Data(#"{"loginId":"new","authUrl":"https://auth.openai.com/authorize?state=synthetic"}"#.utf8))
        let completion = try flow.ready(reply)
        XCTAssertTrue(completion?.success == true)
        XCTAssertEqual(flow.loginID, "new")
        XCTAssertNotNil(flow.url)
        XCTAssertNil(flow.receive(old), "A canceled login must not finish a replacement login")
    }

    func testLoginRejectsUntrustedURLAndSanitizesFailure() throws {
        var flow = BrowserLoginSession()
        let reply = try JSONDecoder().decode(BrowserLoginReply.self, from: Data(#"{"loginId":"new","authUrl":"https://attacker.test/authorize"}"#.utf8))
        XCTAssertThrowsError(try flow.ready(reply))
        XCTAssertNil(flow.url)
        let failure = try JSONDecoder().decode(BrowserLoginCompletion.self, from: Data(#"{"loginId":"new","success":false,"error":"private-token invalid state"}"#.utf8))
        XCTAssertTrue(failure.failureMessage.contains("newest browser tab"))
        XCTAssertFalse(failure.failureMessage.contains("private-token"))
    }

    func testMalformedAccountsAreNotSilentlyOverwritten() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("accounts.json")
        let invalid = Data("broken settings".utf8)
        try invalid.write(to: file)
        XCTAssertThrowsError(try AccountStorage(root: root).load())
        XCTAssertEqual(try Data(contentsOf: file), invalid)
    }
}

final class ClientTests: XCTestCase {
    func makeClient(timeout: Double = 3, notification: @escaping @Sendable (String, Data) -> Void = { _, _ in }) throws -> CodexClient {
        let fixture = try XCTUnwrap(Bundle.module.url(forResource: "fake-codex", withExtension: "py", subdirectory: "Fixtures"))
        return CodexClient(executable: URL(fileURLWithPath: "/usr/bin/python3"), home: FileManager.default.temporaryDirectory, arguments: [fixture.path], timeoutSeconds: timeout, notification: notification)
    }

    func testConcurrentReadsHandshakeAndNotification() async throws {
        let completion = expectation(description: "Login notification")
        let client = try makeClient { method, _ in if method == "account/login/completed" { completion.fulfill() } }
        async let read = client.call("account/read", as: AccountRead.self)
        async let limits = client.call("account/rateLimits/read", as: UsageSnapshot.self)
        let (account, usage) = try await (read, limits)
        XCTAssertEqual(account.account?.email, "fixture@example.test")
        XCTAssertEqual(usage.meters.first?.remaining, 62)
        struct Login: Decodable, Sendable { var loginId: String; var authUrl: String }
        let login = try await client.call("account/login/start", params: ["type": "chatgpt"], as: Login.self)
        XCTAssertEqual(login.loginId, "fake-login")
        await fulfillment(of: [completion], timeout: 3)
        await client.close()
    }

    func testSeparateProfilesCanReadAndStartLoginConcurrently() async throws {
        let first = try makeClient(timeout: 2)
        let second = try makeClient(timeout: 2)
        do {
            _ = try await first.call("account/read", as: AccountRead.self)
            struct Login: Decodable, Sendable { var loginId: String; var authUrl: String }
            async let usage = first.call("account/rateLimits/read", as: UsageSnapshot.self)
            async let login = second.call("account/login/start", params: ["type": "chatgpt"], as: Login.self)
            let (snapshot, started) = try await (usage, login)
            XCTAssertEqual(snapshot.meters.count, 1)
            XCTAssertEqual(started.loginId, "fake-login")
            await first.close(); await second.close()
        } catch { await first.close(); await second.close(); throw error }
    }

    func testBackendErrorsDoNotExposeCredentials() async throws {
        let client = try makeClient()
        do { _ = try await client.call("account/read", params: ["mode": "error"], as: AccountRead.self); XCTFail("Expected error") }
        catch { XCTAssertFalse(error.localizedDescription.contains("private-token")); XCTAssertTrue(error.localizedDescription.contains("sign in")) }
        await client.close()
    }

    func testTimeoutAndProcessExitCanReconnect() async throws {
        let client = try makeClient(timeout: 1)
        do { _ = try await client.call("account/read", params: ["mode": "hang"], as: AccountRead.self); XCTFail("Expected timeout") }
        catch { XCTAssertTrue(error.localizedDescription.contains("too long")) }
        do { _ = try await client.call("account/read", params: ["mode": "exit"], as: AccountRead.self); XCTFail("Expected disconnect") }
        catch { XCTAssertTrue(error.localizedDescription.contains("disconnected")) }
        let read = try await client.call("account/read", as: AccountRead.self)
        XCTAssertEqual(read.account?.planType, "plus")
        await client.close()
    }

    func testReadOnlyBridgeRejectsRedemption() async throws {
        let client = try makeClient()
        do { _ = try await client.call("account/rateLimitResetCredit/consume", as: AccountRead.self); XCTFail("Expected rejection") }
        catch { XCTAssertTrue(error.localizedDescription.contains("read-only")) }
        await client.close()
    }
}
