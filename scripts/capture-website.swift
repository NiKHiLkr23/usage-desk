import AppKit
import SwiftUI

@main struct ProductCapture {
    @MainActor static func main() {
        _ = NSApplication.shared
        NSApp.setActivationPolicy(.prohibited)
        NSApp.appearance = NSAppearance(named: .aqua)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try! FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        let store = AccountStore(demo: true)
        for tab in ["usage", "accounts", "resets"] {
            let navigation = DeskNavigation()
            navigation.usageTab = tab
            let root = DeskRootView(store: store, navigation: navigation).environment(\.colorScheme, .light)
            let view = NSHostingView(rootView: root)
            let rect = NSRect(x: 0, y: 0, width: 420, height: 500)
            let window = NSWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
            window.contentView = view
            view.frame = rect
            window.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.4))
            view.layoutSubtreeIfNeeded()
            let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 840, pixelsHigh: 1000, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
            bitmap.size = rect.size
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try! bitmap.representation(using: .png, properties: [:])!.write(to: output.appendingPathComponent("showcase-\(tab).png"))
            window.contentView = nil
        }
        print("Captured actual SwiftUI views with AccountStore(demo: true); no real account access.")
    }
}
