import XCTest
@testable import ResetDesk

final class PanelResizeAnimatorTests: XCTestCase {
    @MainActor func testResizeProducesIntermediateSizesAndSettlesExactly() async {
        let animator = PanelResizeAnimator()
        let finished = expectation(description: "Resize completed")
        let start = NSSize(width: 420, height: 500)
        let end = NSSize(width: 660, height: 600)
        var frames: [NSSize] = []
        animator.resize(from: start, to: end, animated: true) { size in
            frames.append(size)
            if size == end { finished.fulfill() }
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertGreaterThan(frames.count, 2)
        XCTAssertTrue(frames.contains { $0.width > start.width && $0.width < end.width })
        XCTAssertEqual(frames.last, end)
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $0.width <= $1.width })
    }

    @MainActor func testReversingTransitionCancelsOldDestination() async {
        let animator = PanelResizeAnimator()
        let finished = expectation(description: "Reversed resize completed")
        let compact = NSSize(width: 420, height: 500)
        let expanded = NSSize(width: 660, height: 600)
        var reversed = false
        var lastSize = compact
        animator.resize(from: compact, to: expanded, animated: true) { size in
            lastSize = size
            if size.width > 460, !reversed {
                reversed = true
                animator.resize(from: size, to: compact, animated: true) { reversedSize in
                    lastSize = reversedSize
                    if reversedSize == compact { finished.fulfill() }
                }
            }
            XCTAssertNotEqual(size, expanded, "The superseded transition must never finish")
        }
        await fulfillment(of: [finished], timeout: 2)
        XCTAssertTrue(reversed)
        XCTAssertEqual(lastSize, compact)
    }

    @MainActor func testReducedMotionSnapsAndCancelsInFlightResize() async {
        let animator = PanelResizeAnimator()
        let compact = NSSize(width: 420, height: 500)
        let expanded = NSSize(width: 660, height: 600)
        var delivered: [NSSize] = []
        animator.resize(from: compact, to: expanded, animated: true) { delivered.append($0) }
        animator.resize(from: expanded, to: compact, animated: false) { delivered.append($0) }
        XCTAssertEqual(delivered, [compact])
        await Task.yield()
        XCTAssertEqual(delivered, [compact])
    }
}
