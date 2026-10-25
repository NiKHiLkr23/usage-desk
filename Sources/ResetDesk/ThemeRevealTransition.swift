import AppKit
import QuartzCore
import SwiftUI

/// A short-lived picture of this app's own content. Never saved or sent anywhere.
@MainActor final class ThemeRevealTransition: NSObject {
    static let shared = ThemeRevealTransition()
    private var overlay: NSImageView?
    private var cleanup: DispatchWorkItem?

    override private init() {
        super.init()
        NSWorkspace.shared.notificationCenter.addObserver(self,
            selector: #selector(displayOptionsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    @objc private func displayOptionsChanged() {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { cancel() }
    }

    func cancel() {
        cleanup?.cancel()
        cleanup = nil
        overlay?.layer?.mask?.removeAllAnimations()
        overlay?.removeFromSuperview()
        overlay = nil
    }

    func perform(from anchor: NSView?, change: () -> Void) {
        cancel()
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let anchor, let host = anchor.window?.contentView,
              host.bounds.width > 0, host.bounds.height > 0,
              let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
            change()
            return
        }
        let wasDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let image = NSImage(size: host.bounds.size)
        image.addRepresentation(bitmap)
        let cover = ThemeRevealCover(frame: host.bounds)
        cover.image = image
        cover.imageScaling = .scaleAxesIndependently
        cover.autoresizingMask = [.width, .height]
        cover.wantsLayer = true
        host.addSubview(cover)
        overlay = cover
        change()
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        guard wasDark != isDark else { cancel(); return }
        host.layoutSubtreeIfNeeded()
        let center = cover.convert(NSPoint(x: anchor.bounds.midX, y: anchor.bounds.midY), from: anchor)
        let radius = hypot(max(center.x, cover.bounds.width - center.x),
                           max(center.y, cover.bounds.height - center.y)) + 2
        func maskPath(radius: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.addRect(cover.bounds)
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius,
                                      width: radius * 2, height: radius * 2))
            return path
        }
        let mask = CAShapeLayer()
        mask.frame = cover.bounds
        mask.fillRule = .evenOdd
        mask.fillColor = NSColor.black.cgColor
        mask.path = maskPath(radius: radius)
        cover.layer?.mask = mask
        let reveal = CABasicAnimation(keyPath: "path")
        reveal.fromValue = maskPath(radius: 0.01)
        reveal.toValue = mask.path
        reveal.duration = 0.48
        reveal.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        mask.add(reveal, forKey: "appearanceReveal")
        let completion = DispatchWorkItem { [weak self, weak cover] in
            guard let self, let cover, self.overlay === cover else { return }
            self.cancel()
        }
        cleanup = completion
        DispatchQueue.main.asyncAfter(deadline: .now() + reveal.duration, execute: completion)
    }
}

/// The appearance effect never consumes a click or delays the next action.
@MainActor private final class ThemeRevealCover: NSImageView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override func isAccessibilityElement() -> Bool { false }
}

@MainActor final class ThemeRevealOrigin: ObservableObject {
    weak var view: NSView?
}

struct ThemeRevealAnchor: NSViewRepresentable {
    let origin: ThemeRevealOrigin
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        origin.view = view
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) { origin.view = nsView }
}
