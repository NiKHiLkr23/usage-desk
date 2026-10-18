import AppKit

/// A short interruptible ease-out; AppKit still owns anchoring and screen fitting.
/// No nested animation hints or blocking loops, and no repeated SwiftUI model updates.
@MainActor final class PanelResizeAnimator {
    private var task: Task<Void, Never>?
    private var target: NSSize?

    func cancel() {
        task?.cancel()
        task = nil
        target = nil
    }

    func resize(from start: NSSize, to end: NSSize, animated: Bool,
                update: @escaping @MainActor (NSSize) -> Void) {
        // Navigation can report the same route twice. Don't restart a running tween.
        if animated, target == end { return }
        cancel()
        guard animated, start != end else { update(end); return }
        target = end
        task = Task { @MainActor [weak self] in
            let clock = ContinuousClock()
            let started = clock.now
            let duration = 0.28
            while !Task.isCancelled {
                let elapsed = started.duration(to: clock.now).components
                let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
                let progress = min(1, seconds / duration)
                let eased = 1 - pow(1 - progress, 3)
                update(NSSize(width: start.width + (end.width - start.width) * eased,
                              height: start.height + (end.height - start.height) * eased))
                if progress >= 1 { break }
                do { try await Task.sleep(for: .milliseconds(8)) }
                catch { return }
            }
            guard !Task.isCancelled else { return }
            self?.target = nil
            self?.task = nil
        }
    }
}
