import Combine
import IOKit.pwr_mgt

/// Owns only this app's process-scoped idle-system-sleep assertion. macOS removes
/// it if the process exits, including a crash; no helper process can outlive us.
protocol IdleSleepAssertionBackend {
    func create() -> (IOReturn, IOPMAssertionID)
    func release(_ id: IOPMAssertionID) -> IOReturn
}

struct SystemIdleSleepAssertion: IdleSleepAssertionBackend {
    func create() -> (IOReturn, IOPMAssertionID) {
        var id = IOPMAssertionID(0)
        let result = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Usage Desk — Keep awake" as CFString, &id)
        return (result, id)
    }
    func release(_ id: IOPMAssertionID) -> IOReturn { IOPMAssertionRelease(id) }
}

@MainActor final class KeepAwakeController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var error: String?
    private let backend: IdleSleepAssertionBackend
    private var assertionID: IOPMAssertionID?

    init(backend: IdleSleepAssertionBackend = SystemIdleSleepAssertion()) { self.backend = backend }

    func toggle() { setEnabled(!isEnabled) }
    func dismissError() { error = nil }

    func setEnabled(_ enabled: Bool) {
        guard enabled != isEnabled else { return }
        if enabled {
            let (result, id) = backend.create()
            guard result == kIOReturnSuccess else {
                error = "macOS could not enable Keep awake (\(result)). Try again."
                return
            }
            assertionID = id
            isEnabled = true
        } else if let id = assertionID {
            let result = backend.release(id)
            guard result == kIOReturnSuccess else {
                // Retain ownership and the active indication so a retry can
                // release this exact assertion. Never claim success on failure.
                error = "macOS could not turn off Keep awake (\(result)). Try again, or quit Usage Desk to release it."
                return
            }
            assertionID = nil
            isEnabled = false
        }
        error = nil
    }

    func shutdown() { setEnabled(false) }
    deinit { if let id = assertionID { _ = backend.release(id) } }
}
