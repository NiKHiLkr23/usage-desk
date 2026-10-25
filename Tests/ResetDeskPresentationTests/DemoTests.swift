import XCTest
import ResetDeskCore
@testable import ResetDesk

final class DemoTests: XCTestCase {
    @MainActor func testProviderIconsAreBundled() {
        for provider in ResetDeskCore.AccountProvider.allCases {
            let image = ProviderIcon.image(for: provider)
            XCTAssertNotNil(image)
            XCTAssertGreaterThan(image?.size.width ?? 0, 0)
        }
    }
    @MainActor func testDemoUsesOnlySyntheticAccountsAndCannotAuthenticate() async throws {
        let store = AccountStore(demo: true)
        defer { store.shutdown() }
        XCTAssertTrue(store.isDemo)
        XCTAssertEqual(store.accounts.count, 3)
        XCTAssertTrue(store.accounts.allSatisfy { $0.home.hasPrefix("/demo/") })
        XCTAssertTrue(store.states.values.allSatisfy { $0.info?.email?.hasSuffix("@example.com") == true })
        XCTAssertTrue(store.states.values.allSatisfy { $0.usage?.meters.count == 2 })
        XCTAssertTrue(store.chromeProfiles.isEmpty)
        XCTAssertTrue(store.accounts.contains(where: { $0.provider == .claude }))
        XCTAssertThrowsError(try store.connectClaude(label: "Private", home: "/synthetic/home"))
        let prior = store.selectedState.usage?.meters.first?.remaining
        await store.refresh("current")
        XCTAssertEqual(store.selectedState.usage?.meters.first?.remaining, prior)
        do {
            try await store.beginSignIn("work", chromeProfile: nil)
            XCTFail("Demo sign-in must be blocked")
        } catch { XCTAssertNil(store.pendingLogin) }
        XCTAssertThrowsError(try store.createAccount(label: "Not real", chromeProfile: nil, expectedEmail: nil))
    }
}
