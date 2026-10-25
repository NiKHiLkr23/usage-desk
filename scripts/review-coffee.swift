// Isolated review entry point. Compiled in a temporary package by review-coffee.sh.
// Movie frames render the real SwiftUI CoffeeGlyph deterministically; they are
// native animation studies, not screen recordings of account-bearing app UI.
import AppKit
import SwiftUI

struct CoffeeStudy: View {
    let variant: CoffeeAnimation
    let progress: Double
    let active: Bool
    let hovering: Bool
    let stage: String
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("\(variant.rawValue.capitalized) / Keep awake").font(.system(size: 26, weight: .semibold))
            Text("Native SwiftUI animation study · synthetic footer · 32 pt targets")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Circle().fill(active ? Color.brown : Color.secondary).frame(width: 6, height: 6)
                Text(stage).font(.system(size: 13, weight: .medium))
                Spacer()
                Text(active ? "KEEP AWAKE ON" : "KEEP AWAKE OFF").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
            }.frame(height: 22)
            ForEach([false, true], id: \.self) { dark in
                HStack {
                    Text(dark ? "Dark" : "Light").font(.system(size: 11)).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
                    footer(dark: dark)
                    Spacer()
                    CoffeeGlyph(variant: variant, progress: progress, active: active)
                        .foregroundStyle(dark ? Color.white : Color.black)
                        .frame(width: 80, height: 80)
                        .padding(18).background(dark ? Color(white: 0.08) : Color(white: 0.98), in: RoundedRectangle(cornerRadius: 12))
                        .environment(\.colorScheme, dark ? .dark : .light)
                }
            }
            HStack {
                Text("Normal footer scale").frame(width: 474, alignment: .center)
                Spacer()
                Text("4× detail").frame(width: 116)
            }.font(.system(size: 11)).foregroundStyle(.secondary)
            Divider()
            Text("Hover plays once, holds, then resets on exit. Active fill + dot remain at rest.")
                .font(.system(size: 12))
            Text("Prevents idle system sleep only. Display policy is unchanged. Stops on quit.")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }.padding(28).frame(width: 760, height: 540).foregroundStyle(Color(white: 0.14)).background(Color(white: 0.94))
    }
    private func footer(dark: Bool) -> some View {
        HStack(spacing: 6) {
            Circle().fill(Color(red: 0.24, green: 0.55, blue: 0.36)).frame(width: 5, height: 5)
            Text("Live"); Text("· just now").foregroundStyle(.secondary)
            Spacer()
            CoffeeGlyph(variant: variant, progress: progress, active: active).frame(width: 20, height: 20)
                .frame(width: 32, height: 32)
                .background(hovering ? Color.primary.opacity(0.065) : .clear, in: Circle())
            Image(systemName: "power").font(.system(size: 14)).frame(width: 32, height: 32).foregroundStyle(.secondary)
        }.font(.system(size: 10)).padding(.horizontal, 20).frame(width: 420, height: 56)
            .foregroundStyle(dark ? Color.white : Color.black)
            .background(dark ? Color(white: 0.08) : Color(white: 0.98), in: RoundedRectangle(cornerRadius: 9))
            .environment(\.colorScheme, dark ? .dark : .light)
    }
}

struct CoffeeReviewWindow: View {
    @ObservedObject var controller: KeepAwakeController
    @State private var variant = CoffeeAnimation.brew
    @State private var dark = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Coffee motion review").font(.title2.bold())
            Text("Synthetic isolated native preview. Buttons toggle a real app-owned idle-sleep assertion; quit releases it.")
                .font(.caption).foregroundStyle(.secondary)
            Picker("Animation", selection: $variant) { ForEach(CoffeeAnimation.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) } }.pickerStyle(.segmented)
            Toggle("Dark appearance", isOn: $dark)
            HStack {
                Text("Live · just now").font(.system(size: 10)).foregroundStyle(.secondary)
                Spacer()
                CoffeeButton(controller: controller, variant: variant)
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.buttonStyle(DeskIconButton()).help("Quit review and release Keep awake")
            }.padding(16).background(DeskTheme.background, in: RoundedRectangle(cornerRadius: 10))
            HStack(spacing: 40) {
                ForEach(CoffeeAnimation.allCases, id: \.self) { choice in
                    VStack(spacing: 10) {
                        CoffeeButton(controller: controller, variant: choice).scaleEffect(3).frame(width: 110, height: 110)
                        Text(choice.rawValue.capitalized).font(.caption)
                    }
                }
            }
            Text(controller.isEnabled ? "Keep awake is ON — click a coffee button to turn off." : "Keep awake is OFF — hover any coffee button to compare.").font(.callout)
        }.padding(28).frame(width: 560).environment(\.colorScheme, dark ? .dark : .light)
            .background(dark ? Color(white: 0.08) : Color(white: 0.98))
            .foregroundStyle(dark ? Color.white : Color.black)
    }
}

@MainActor final class CoffeeReviewDelegate: NSObject, NSApplicationDelegate {
    let controller = KeepAwakeController()
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: CoffeeReviewWindow(controller: controller))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 616, height: 450), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Usage Desk — Coffee Review (isolated)"
        window.contentView = host; window.center(); window.makeKeyAndOrderFront(nil)
        self.window = window; NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { controller.shutdown() }
}

@main struct CoffeeReview {
    @MainActor static func main() throws {
        _ = NSApplication.shared
        if CommandLine.arguments.contains("--interactive") {
            NSApp.setActivationPolicy(.regular)
            let delegate = CoffeeReviewDelegate(); NSApp.delegate = delegate; NSApp.run()
            withExtendedLifetime(delegate) {}
            return
        }
        NSApp.setActivationPolicy(.prohibited)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        for variant in CoffeeAnimation.allCases { try record(variant, output: output) }
    }

    @MainActor static func record(_ variant: CoffeeAnimation, output: URL) throws {
        let url = output.appendingPathComponent("\(variant.rawValue)-native-study.mp4")
        try? FileManager.default.removeItem(at: url)
        let frames = output.appendingPathComponent(".frames-\(variant.rawValue)", isDirectory: true)
        try FileManager.default.createDirectory(at: frames, withIntermediateDirectories: true)
        let fps = 30
        for frame in 0..<240 {
            let t = Double(frame) / Double(fps)
            let active = t >= 3 && t < 5.7
            let start: Double? = t >= 0.8 && t < 2.4 ? 0.8 : t >= 3.4 && t < 5 ? 3.4 : t >= 6 && t < 6.3 ? 6 : t >= 6.6 ? 6.6 : nil
            let p = start.map { min(1, (t - $0) / (variant == .steam ? 0.75 : 0.85)) } ?? 0
            let stage = start != nil ? (p < 1 ? "Hover → forward" : "Hover → hold") : active ? "Mouse exit · active at rest" : t < 0.8 ? "Rest" : "Mouse exit · reset"
            let root = CoffeeStudy(variant: variant, progress: p, active: active, hovering: start != nil, stage: stage)
            let renderer = ImageRenderer(content: root); renderer.scale = 2
            guard let cgImage = renderer.cgImage else { fatalError("SwiftUI rendering failed") }
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            let png = bitmap.representation(using: .png, properties: [:])!
            try png.write(to: frames.appendingPathComponent(String(format: "%04d.png", frame)))
            if frame == 55 { try png.write(to: output.appendingPathComponent("\(variant.rawValue)-native-study.png")) }
        }
        let encoder = Process()
        encoder.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        encoder.arguments = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", String(fps), "-i", frames.appendingPathComponent("%04d.png").path, "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-movflags", "+faststart", url.path]
        try encoder.run(); encoder.waitUntilExit()
        guard encoder.terminationStatus == 0 else { throw NSError(domain: "CoffeeReview", code: Int(encoder.terminationStatus)) }
        try FileManager.default.removeItem(at: frames)
        print("Recorded \(url.path)")
    }
}
