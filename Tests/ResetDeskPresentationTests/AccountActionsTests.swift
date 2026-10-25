import XCTest
import ResetDeskCore
@testable import ResetDesk

final class AccountActionsTests: XCTestCase {
    @MainActor func testRenameChangesOnlyLabelAndRejectsInvalidInput() throws {
        let store = AccountStore(demo: true)
        defer { store.shutdown() }
        store.selectedID = "work"
        let original = try XCTUnwrap(store.accounts.first { $0.id == "lab" })
        let usage = store.states["lab"]?.usage?.meters.first?.remaining
        try store.renameAccount("lab", label: "  Claude personal  ")
        var expected = original
        expected.label = "Claude personal"
        XCTAssertEqual(store.accounts.first { $0.id == "lab" }, expected)
        XCTAssertEqual(store.selectedID, "work")
        XCTAssertEqual(store.states["lab"]?.usage?.meters.first?.remaining, usage)
        for bad in ["  ", String(repeating: "a", count: 81), "Work\nPersonal", "Work\tPersonal"] {
            XCTAssertThrowsError(try store.renameAccount("lab", label: bad))
            XCTAssertEqual(store.accounts.first { $0.id == "lab" }, expected)
        }
        XCTAssertThrowsError(try store.renameAccount("removed", label: "Work"))
        try store.renameAccount("current", label: "Personal Codex")
        XCTAssertEqual(store.accounts.first { $0.id == "current" }?.label, "Personal Codex")
    }

    @MainActor func testOnlyUsableMatchedConnectionsSelectAnAccount() throws {
        let store = AccountStore(demo: true)
        defer { store.shutdown() }
        let good = try XCTUnwrap(store.states["work"])
        let prior = store.selectedID
        var failure = good
        failure.error = "Offline"
        store.states["work"] = failure
        store.completeConnection("work")
        XCTAssertNil(store.connectionCompleted)
        XCTAssertEqual(store.selectedID, prior)
        failure = good; failure.usage = nil
        store.states["work"] = failure
        store.completeConnection("work")
        XCTAssertNil(store.connectionCompleted)
        failure = good
        failure.info = AccountRead.Info(type: "chatgpt", email: "different@example.com", planType: "plus")
        store.states["work"] = failure
        store.completeConnection("work")
        XCTAssertNil(store.connectionCompleted)
        XCTAssertEqual(store.selectedID, prior)
        store.states["work"] = good
        store.completeConnection("work")
        XCTAssertEqual(store.connectionCompleted?.accountID, "work")
        XCTAssertEqual(store.selectedID, "work")
        let event = store.connectionCompleted
        store.completeConnection("work")
        XCTAssertNotEqual(store.connectionCompleted, event, "Reconnecting the same account emits a fresh event")
    }

    @MainActor func testQuickSummaryShowsQuotaAndResetWithoutTreatingStaleAsLive() throws {
        let store = AccountStore(demo: true)
        defer { store.shutdown() }
        let now = Date()
        var state = try XCTUnwrap(store.states["work"])
        let ready = AccountQuickSummary(state: state, now: now)
        XCTAssertEqual(ready.title, "42% left")
        XCTAssertTrue(ready.detail?.hasPrefix("Resets in") == true)
        XCTAssertEqual(AccountQuickSummary(state: state, signingIn: true).title, "Signing in…")
        state.error = "Offline"
        let stale = AccountQuickSummary(state: state)
        XCTAssertEqual(stale.title, "Needs attention")
        XCTAssertEqual(stale.detail, "Last known usage")
        state.signedOut = true
        XCTAssertTrue(AccountQuickSummary(state: state).needsConnection)
        XCTAssertEqual(AccountQuickSummary(state: state).title, "Sign-in needed")
        state.error = nil; state.signedOut = false
        XCTAssertEqual(AccountQuickSummary(state: state, now: now.addingTimeInterval(9000)).detail, "Awaiting update")
        state.usage = nil
        XCTAssertEqual(AccountQuickSummary(state: state).title, "Not reported")
        state.isLoading = true
        XCTAssertEqual(AccountQuickSummary(state: state).title, "Updating…")
    }
}
