import SwiftUI
import ResetDeskCore

/// Never present cached percentages as live when a profile needs attention.
struct AccountQuickSummary {
    var title: String
    var detail: String?
    var color: Color = DeskTheme.muted
    var needsConnection = false

    init(state: AccountState?, signingIn: Bool = false, now: Date = .now) {
        guard !signingIn else { title = "Signing in…"; return }
        guard let state else { title = "Loading…"; return }
        if state.signedOut || state.unsupported {
            title = "Sign-in needed"; color = DeskTheme.amber; needsConnection = true; return
        }
        if state.error != nil {
            title = "Needs attention"; detail = state.usage == nil ? nil : "Last known usage"; color = DeskTheme.amber; return
        }
        guard let meter = state.usage?.meters.first else {
            title = state.isLoading ? "Updating…" : "Not reported"; return
        }
        title = meter.remaining <= 0 ? "Exhausted" : "\(Int(meter.remaining.rounded()))% left"
        color = DeskTheme.quota(meter.remaining)
        if let reset = meter.resetDate {
            detail = reset <= now ? "Awaiting update" : "Resets in \(countdown(reset, now: now))"
        }
        if state.isLoading { detail = "Updating…" }
    }
}
