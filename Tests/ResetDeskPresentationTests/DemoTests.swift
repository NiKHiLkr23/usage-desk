import XCTest
import AppKit
import SwiftUI
import ResetDeskCore
@testable import ResetDesk

final class DemoTests: XCTestCase {
    @MainActor func testProviderIconsAreBundled() {
        for provider in ResetDeskCore.AccountProvider.allCases {
            let image = ProviderIcon.image(for: provider)
            XCTAssertNotNil(image)
            XCTAssertEqual(image?.size.width, 18)
            let menuImage = ProviderIcon.image(for: provider, size: 14)
            XCTAssertEqual(menuImage?.size.width, 14)
            XCTAssertEqual(menuImage?.size.height, 14)
            XCTAssertEqual(menuImage?.isTemplate, true)
        }
    }
    @MainActor func testNativeMenuIconsKeepSizeAndContrastInBothAppearances() throws {
        for provider in AccountProvider.allCases {
            for scheme in [ColorScheme.light, .dark] {
                let image = try XCTUnwrap(ProviderIcon.menuImage(for: provider, colorScheme: scheme))
                XCTAssertEqual(image.size, NSSize(width: 14, height: 14))
                let cgImage = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
                let pixels = NSBitmapImageRep(cgImage: cgImage)
                var opaque: NSColor?
                for y in 0..<pixels.pixelsHigh {
                    for x in 0..<pixels.pixelsWide {
                        if let color = pixels.colorAt(x: x, y: y), color.alphaComponent > 0.999 { opaque = color; break }
                    }
                    if opaque != nil { break }
                }
                let color = try XCTUnwrap(opaque, "Provider menu icon must have visible pixels")
                if provider == .claude {
                    let expected = try XCTUnwrap(DeskTheme.claudeColor.usingColorSpace(.sRGB))
                    XCTAssertEqual(color.redComponent, expected.redComponent, accuracy: 0.03)
                    XCTAssertEqual(color.greenComponent, expected.greenComponent, accuracy: 0.03)
                    XCTAssertEqual(color.blueComponent, expected.blueComponent, accuracy: 0.03)
                } else if scheme == .dark { XCTAssertGreaterThan(color.redComponent, 0.9) }
                else { XCTAssertLessThan(color.redComponent, 0.1) }
            }
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
