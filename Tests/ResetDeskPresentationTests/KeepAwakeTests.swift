import XCTest
import IOKit.pwr_mgt
@testable import ResetDesk

private final class FakeIdleSleep: IdleSleepAssertionBackend {
    var createResult: IOReturn = kIOReturnSuccess
    var releaseResult: IOReturn = kIOReturnSuccess
    var created = 0
    var released: [IOPMAssertionID] = []
    func create() -> (IOReturn, IOPMAssertionID) {
        created += 1
        return (createResult, IOPMAssertionID(40 + created))
    }
    func release(_ id: IOPMAssertionID) -> IOReturn { released.append(id); return releaseResult }
}

final class KeepAwakeTests: XCTestCase {
    @MainActor func testRealSystemAssertionCreateInspectAndReleaseWhenOptedIn() throws {
        guard ProcessInfo.processInfo.environment["USAGE_DESK_TEST_POWER_ASSERTION"] == "1" else {
            throw XCTSkip("Real sleep assertions are explicit opt-in; offline tests use a fake backend.")
        }
        let backend = SystemIdleSleepAssertion()
        for _ in 0..<3 {
            let (result, id) = backend.create()
            XCTAssertEqual(result, kIOReturnSuccess)
            guard result == kIOReturnSuccess else { return }
            var released = false
            defer { if !released { _ = backend.release(id) } }
            let properties = IOPMAssertionCopyProperties(id)?.takeRetainedValue() as? [String: Any]
            XCTAssertEqual(properties?[kIOPMAssertionTypeKey] as? String, kIOPMAssertionTypePreventUserIdleSystemSleep)
            let releaseResult = backend.release(id)
            released = releaseResult == kIOReturnSuccess
            XCTAssertEqual(releaseResult, kIOReturnSuccess)
            XCTAssertNil(IOPMAssertionCopyProperties(id), "The app's assertion must disappear after release")
        }
    }
    @MainActor func testOwnsExactlyOneAssertionAndRepeatedRequestsAreIdempotent() {
        let backend = FakeIdleSleep()
        let owner = KeepAwakeController(backend: backend)
        owner.setEnabled(true); owner.setEnabled(true)
        XCTAssertTrue(owner.isEnabled); XCTAssertEqual(backend.created, 1)
        owner.setEnabled(false); owner.setEnabled(false)
        XCTAssertFalse(owner.isEnabled); XCTAssertEqual(backend.released, [41])
        owner.toggle(); owner.shutdown(); owner.shutdown()
        XCTAssertEqual(backend.released, [41, 42])
    }
    @MainActor func testCreateFailureStaysOffAndCanRetry() {
        let backend = FakeIdleSleep(); backend.createResult = kIOReturnError
        let controller = KeepAwakeController(backend: backend)
        controller.toggle()
        XCTAssertFalse(controller.isEnabled); XCTAssertNotNil(controller.error)
        XCTAssertTrue(backend.released.isEmpty)
        backend.createResult = kIOReturnSuccess; controller.toggle()
        XCTAssertTrue(controller.isEnabled); XCTAssertNil(controller.error)
        controller.shutdown(); XCTAssertEqual(backend.released, [42])
    }
    @MainActor func testReleaseFailureRetainsOwnershipAndActiveStateForRetry() {
        let backend = FakeIdleSleep()
        let owner = KeepAwakeController(backend: backend)
        owner.toggle(); backend.releaseResult = kIOReturnError; owner.toggle()
        XCTAssertTrue(owner.isEnabled); XCTAssertNotNil(owner.error)
        owner.dismissError(); XCTAssertNil(owner.error); XCTAssertTrue(owner.isEnabled)
        backend.releaseResult = kIOReturnSuccess; owner.shutdown()
        XCTAssertFalse(owner.isEnabled); XCTAssertEqual(backend.released, [41, 41])
    }
    @MainActor func testDeinitializationReleasesOnlyItsOwnedAssertion() {
        let backend = FakeIdleSleep()
        var controller: KeepAwakeController? = KeepAwakeController(backend: backend)
        controller?.toggle(); controller = nil
        XCTAssertEqual(backend.released, [41])
    }
    @MainActor func testSeparateOwnersNeverReleaseEachOthersAssertions() {
        let backend = FakeIdleSleep()
        let first = KeepAwakeController(backend: backend), second = KeepAwakeController(backend: backend)
        first.toggle(); second.toggle(); first.shutdown()
        XCTAssertEqual(backend.released, [41]); XCTAssertTrue(second.isEnabled)
        second.shutdown(); XCTAssertEqual(backend.released, [41, 42])
    }
}
