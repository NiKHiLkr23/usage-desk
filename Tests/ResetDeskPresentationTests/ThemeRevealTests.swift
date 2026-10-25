import XCTest
import AppKit
import SwiftUI
@testable import ResetDesk

final class ThemeRevealTests: XCTestCase {
    @MainActor func testSwiftUIAppearanceUpdatePreservesOverlayAndCleanup() async throws {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            throw XCTSkip("Reduce Motion intentionally disables the overlay.")
        }
        _ = NSApplication.shared
        let originalAppearance = NSApp.appearance
        let store = AccountStore(demo: true)
        let root = DeskRootView(store: store, navigation: DeskNavigation())
        let controller = DeskHostingController(rootView: root)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 500),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        defer {
            ThemeRevealTransition.shared.cancel()
            window.orderOut(nil)
            window.contentViewController = nil
            store.shutdown()
            NSApp.appearance = originalAppearance
        }
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 420, height: 500))
        window.orderFront(nil)
        // Allow the real SwiftUI panel to finish its initial layout before capture.
        try await Task.sleep(for: .milliseconds(60))
        DeskAppearance.light.applyToApp()
        let anchor = try XCTUnwrap(controller.view.subviews.first)
        ThemeRevealTransition.shared.perform(from: anchor) { DeskAppearance.dark.applyToApp() }
        let cover = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? NSImageView }.first)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertTrue(cover.superview === controller.view)
        XCTAssertNotNil(cover.layer?.mask, "Appearance changes must not discard the mask.")
        XCTAssertTrue(cover.layer?.superlayer === controller.view.layer,
                      "The effect must remain in the displayed layer tree, not merely the NSView tree.")
        ThemeRevealTransition.shared.perform(from: anchor) { DeskAppearance.light.applyToApp() }
        XCTAssertEqual(controller.view.subviews.filter { $0 is NSImageView }.count, 1)
        try await Task.sleep(for: .milliseconds(550))
        XCTAssertTrue(controller.view.subviews.allSatisfy { !($0 is NSImageView) })
    }
}
