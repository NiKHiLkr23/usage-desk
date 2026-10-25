import XCTest
@testable import ResetDesk
import ResetDeskCore

final class NavigationTests: XCTestCase {
    @MainActor func testManagementBackReturnsToQuickAccountsAndRetainsSelection() async {
        let navigation = DeskNavigation()
        let compact = navigation.size
        navigation.manageAccounts(selectedID: "work")
        XCTAssertEqual(navigation.accountSelection, "work")
        XCTAssertGreaterThan(navigation.size.width, compact.width)
        navigation.showPreferences()
        navigation.back()
        XCTAssertEqual(navigation.page, .accounts)
        navigation.back()
        XCTAssertEqual(navigation.page, .usage)
        XCTAssertEqual(navigation.usageTab, "accounts")
        XCTAssertEqual(navigation.accountSelection, "work")
        XCTAssertEqual(navigation.size, compact)
    }

    @MainActor func testAddAccountOpensBlankManagementAndViewUsageLeavesQuickList() async {
        let navigation = DeskNavigation()
        navigation.manageAccounts(selectedID: "work")
        navigation.back()
        navigation.manageAccounts(selectedID: nil)
        XCTAssertNil(navigation.accountSelection)
        navigation.back()
        XCTAssertEqual(navigation.usageTab, "accounts")
        navigation.showUsage()
        XCTAssertEqual(navigation.page, .usage)
        XCTAssertEqual(navigation.usageTab, "usage")
    }

    @MainActor func testAccountDraftSurvivesPreferencesRoundTrip() async {
        let navigation = DeskNavigation()
        navigation.page = .accounts
        let draft = navigation.draft(for: nil)
        draft.label = "Work"
        draft.chrome = "Profile 2"
        draft.email = "work@example.com"
        navigation.showPreferences()
        navigation.back()
        XCTAssertEqual(navigation.page, .accounts)
        XCTAssertTrue(navigation.draft(for: nil) === draft)
        XCTAssertEqual(navigation.draft(for: nil).email, "work@example.com")
        XCTAssertEqual(navigation.draft(for: nil).chrome, "Profile 2")
    }

    @MainActor func testCreatedAccountRetainsDraftButNextAccountStartsEmpty() async {
        let navigation = DeskNavigation()
        let draft = navigation.draft(for: nil)
        draft.label = "Work"
        navigation.createdAccount("created-id")
        XCTAssertEqual(navigation.accountSelection, "created-id")
        let saved = LocalAccount(id: "created-id", label: "Work", home: "/unused-test-home")
        XCTAssertTrue(navigation.draft(for: saved) === draft)
        // The next Add account form must not inherit the previous account's email or browser.
        let next = navigation.draft(for: nil)
        XCTAssertFalse(next === draft)
        XCTAssertEqual(next.label, "")
        XCTAssertEqual(next.chrome, "default-browser")
        XCTAssertEqual(next.email, "")
    }

    @MainActor func testProviderChoiceSurvivesNavigationAndNewDraftResets() async {
        let navigation = DeskNavigation()
        let draft = navigation.draft(for: nil)
        draft.provider = .claude
        draft.claudeHome = "/synthetic/claude-work"
        navigation.page = .accounts
        navigation.showPreferences(); navigation.back()
        XCTAssertEqual(navigation.draft(for: nil).provider, .claude)
        XCTAssertEqual(navigation.draft(for: nil).claudeHome, "/synthetic/claude-work")
        navigation.createdAccount("claude-work")
        let saved = LocalAccount(id: "claude-work", label: "Work", home: "/synthetic/claude-work", managed: false, provider: .claude)
        XCTAssertTrue(navigation.draft(for: saved) === draft)
        XCTAssertEqual(navigation.draft(for: nil).provider, .codex)
    }

    @MainActor func testBackRestoresResetsAndCompactSize() async {
        let navigation = DeskNavigation()
        navigation.usageTab = "resets"
        navigation.resetTab = "schedule"
        let compact = navigation.size
        navigation.page = .accounts
        XCTAssertGreaterThan(navigation.size.width, compact.width)
        navigation.showPreferences()
        navigation.showPreferences()
        navigation.back()
        XCTAssertEqual(navigation.page, .accounts)
        navigation.back()
        XCTAssertEqual(navigation.page, .usage)
        XCTAssertEqual(navigation.size, compact)
        XCTAssertEqual(navigation.usageTab, "resets")
        XCTAssertEqual(navigation.resetTab, "schedule")
    }
}
