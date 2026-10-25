import AppKit
import XCTest
import SwiftUI
import IOKit.pwr_mgt
@testable import ResetDesk

private final class MotionTestBackend: IdleSleepAssertionBackend {
    var created = 0
    var released = 0
    func create() -> (IOReturn, IOPMAssertionID) { created += 1; return (kIOReturnSuccess, 123) }
    func release(_ id: IOPMAssertionID) -> IOReturn { released += 1; return kIOReturnSuccess }
}

final class CoffeeMotionTests: XCTestCase {
    func testLoopHasMatchingPositionAndVelocityAcrossSeams() {
        let period = CoffeeLoopFrame.period
        let epsilon = 0.00001
        for elapsed in [0.0, 0.37, period, period * 10] {
            let frame = CoffeeLoopFrame(elapsed: elapsed)
            let next = CoffeeLoopFrame(elapsed: elapsed + period)
            XCTAssertEqual(frame.wave, next.wave, accuracy: 0.000001)
            XCTAssertEqual(frame.steamSway, next.steamSway, accuracy: 0.000001)
            XCTAssertEqual(frame.steamLift, next.steamLift, accuracy: 0.000001)
            XCTAssertEqual(frame.steamOpacity, next.steamOpacity, accuracy: 0.000001)
        }
        let before = CoffeeLoopFrame(elapsed: period - epsilon)
        let seam = CoffeeLoopFrame(elapsed: period)
        let after = CoffeeLoopFrame(elapsed: period + epsilon)
        XCTAssertEqual((seam.wave - before.wave) / epsilon, (after.wave - seam.wave) / epsilon, accuracy: 0.001)
        XCTAssertEqual((seam.steamLift - before.steamLift) / epsilon, (after.steamLift - seam.steamLift) / epsilon, accuracy: 0.001)
        XCTAssertNotEqual(CoffeeLoopFrame(elapsed: period / 4).wave, CoffeeLoopFrame(elapsed: period * 3 / 4).wave)
    }

    @MainActor private func pumpAppKit(for duration: TimeInterval) {
        let end = Date().addingTimeInterval(duration)
        while Date() < end {
            if let event = NSApp.nextEvent(matching: .any, until: .now.addingTimeInterval(0.01), inMode: .default, dequeue: true) { NSApp.sendEvent(event) }
            RunLoop.main.run(until: .now.addingTimeInterval(0.01))
        }
    }

    @MainActor func testActualButtonAnimatesOnlyWhenOnAndPreservesOneAssertion() throws {
        #if arch(x86_64)
        // The hosted Intel VM aborts inside Metal when SwiftUI Canvas renders:
        // "Target device architecture is nil". Keep this GPU test on physical
        // Macs/Apple silicon; geometry, visibility and ownership still run here.
        if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
           ProcessInfo.processInfo.environment["RUNNER_ENVIRONMENT"] != "self-hosted" {
            throw XCTSkip("Hosted Intel Metal device cannot render SwiftUI Canvas; run this check on a Mac with a supported GPU.")
        }
        #endif
        _ = NSApplication.shared
        let backend = MotionTestBackend()
        let controller = KeepAwakeController(backend: backend)
        let host = NSHostingView(rootView: AnyView(CoffeeButton(controller: controller).frame(width: 40, height: 40).background(Color.white)))
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 40, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.level = .floating; window.contentView = host
        defer { controller.shutdown(); window.orderOut(nil); window.contentView = nil }
        window.orderFrontRegardless(); pumpAppKit(for: 0.2)
        func snapshot() -> Data {
            host.layoutSubtreeIfNeeded()
            let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds)!
            host.cacheDisplay(in: host.bounds, to: bitmap)
            return bitmap.representation(using: .png, properties: [:])!
        }
        let off = snapshot(); pumpAppKit(for: 0.3)
        XCTAssertEqual(off, snapshot(), "Off does not run a background animation")
        controller.setEnabled(true); pumpAppKit(for: 0.2)
        let active = snapshot(); pumpAppKit(for: 0.6)
        // Hosted macOS runners can enable Reduce Motion. Never change the user's
        // preference or expect motion that the actual button must suppress.
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            XCTAssertEqual(active, snapshot(), "System Reduce Motion keeps the active cup static")
        } else {
            XCTAssertNotEqual(active, snapshot(), "On must move without hover when motion is allowed")
        }
        XCTAssertEqual(backend.created, 1, "Animation cycles must never reacquire an assertion")
        host.rootView = AnyView(CoffeeButton(controller: controller, reduceMotionOverride: true).frame(width: 40, height: 40).background(Color.white))
        pumpAppKit(for: 0.2)
        let reduced = snapshot(); pumpAppKit(for: 0.3)
        XCTAssertEqual(reduced, snapshot(), "Reduce Motion keeps a static active cup")
        XCTAssertTrue(controller.isEnabled)
        window.orderOut(nil); pumpAppKit(for: 0.2)
        XCTAssertTrue(controller.isEnabled, "Hiding the panel must retain the sleep assertion")
        XCTAssertEqual(backend.released, 0)
        controller.setEnabled(false); window.orderFrontRegardless(); pumpAppKit(for: 0.2)
        let stopped = snapshot(); pumpAppKit(for: 0.3)
        XCTAssertEqual(stopped, snapshot(), "Turning Off stops active motion")
        XCTAssertEqual(backend.released, 1)
    }

    @MainActor func testNativeVisibilitySuspendsWhenOwningWindowOrdersOut() {
        _ = NSApplication.shared
        var observed: [Bool] = []
        let reader = CoffeeVisibilityReader.VisibilityView { observed.append($0) }
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 40, height: 40), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = reader
        defer { window.orderOut(nil); window.contentView = nil }
        window.orderFrontRegardless()
        pumpAppKit(for: 0.2)
        XCTAssertEqual(observed.last, true, "Visible native content must enable the animation clock")
        window.orderOut(nil)
        pumpAppKit(for: 0.2)
        XCTAssertEqual(observed.last, false, "A cached but closed popover must suspend its clock")
        window.orderFrontRegardless()
        pumpAppKit(for: 0.2)
        XCTAssertEqual(observed.last, true, "Reopening must resume without reacquiring power assertions")
        window.contentView = nil
        pumpAppKit(for: 0.1)
        XCTAssertEqual(observed.last, false)
    }
}
