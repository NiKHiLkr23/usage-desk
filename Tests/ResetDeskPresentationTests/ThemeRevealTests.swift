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

extension ThemeRevealTests {
    @MainActor func testPopoverColorsFollowThemeAndReleaseSystemOverride() async throws {
        _ = NSApplication.shared
        let originalAppearance = NSApp.appearance
        let suite = "in.nikhilkr.resetdesk.appearance-test." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.set("light", forKey: "usageDeskAppearance")
        let anchorWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 80, height: 30),
                                    styleMask: [.borderless], backing: .buffered, defer: false)
        let anchor = NSView(frame: NSRect(x: 0, y: 0, width: 80, height: 30))
        anchorWindow.contentView = anchor
        anchorWindow.appearance = NSAppearance(named: .darkAqua)
        anchorWindow.orderFront(nil)
        let view = VStack { AppearanceButton(); Spacer() }
            .frame(width: 200, height: 180).background(DeskTheme.background)
            .deskAppearance().defaultAppStorage(defaults)
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = []
        let surface = NSViewController()
        surface.view = NSView(frame: NSRect(x: 0, y: 0, width: 200, height: 180))
        surface.view.wantsLayer = true
        surface.addChild(hosting)
        hosting.view.frame = surface.view.bounds
        hosting.view.autoresizingMask = [.width, .height]
        surface.view.addSubview(hosting.view)
        let panel = NSPopover()
        panel.behavior = .applicationDefined
        panel.animates = false
        panel.contentViewController = surface
        panel.contentSize = NSSize(width: 200, height: 180)
        defer {
            panel.close()
            anchorWindow.orderOut(nil)
            defaults.removePersistentDomain(forName: suite)
            NSApp.appearance = originalAppearance
        }
        panel.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        func backgroundBrightness() throws -> Double {
            let bitmap = try XCTUnwrap(hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds))
            hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmap)
            let pixel = try XCTUnwrap(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
            return pixel.redComponent
        }
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(try backgroundBrightness(), 0.9, "Light must repaint the panel, not just the icon.")
        defaults.set("dark", forKey: "usageDeskAppearance")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertLessThan(try backgroundBrightness(), 0.2, "Dark must repaint the panel.")
        defaults.set("light", forKey: "usageDeskAppearance")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertGreaterThan(try backgroundBrightness(), 0.9)
        defaults.set("system", forKey: "usageDeskAppearance")
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertNil(NSApp.appearance, "System must release the application override.")
        let system = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        XCTAssertEqual(hosting.view.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]), system)
    }
}
