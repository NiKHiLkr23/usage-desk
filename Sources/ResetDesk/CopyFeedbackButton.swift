import SwiftUI
import AppKit

/// Only the result is retained in view state, never the command or authorization URL.
struct CopyFeedbackButton: View {
    let title: String
    let value: () -> String?
    private enum Result { case idle, copied, failed }
    @State private var result: Result = .idle
    @State private var feedbackID = UUID()

    private var text: String {
        switch result {
        case .idle: return title
        case .copied: return "Copied"
        case .failed: return "Copy failed"
        }
    }
    private var symbol: String {
        switch result {
        case .idle: return "doc.on.doc"
        case .copied: return "checkmark"
        case .failed: return "exclamationmark.circle"
        }
    }
    private var feedback: String {
        switch result {
        case .idle: return "Copy to clipboard."
        case .copied: return "Copied to clipboard."
        case .failed: return "Could not copy to the clipboard. Click to try again."
        }
    }

    var body: some View {
        Button {
            if let value = value() {
                NSPasteboard.general.clearContents()
                result = NSPasteboard.general.setString(value, forType: .string) ? .copied : .failed
            } else { result = .failed }
            feedbackID = UUID()
            NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested,
                userInfo: [.announcement: feedback, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        } label: {
            ZStack {
                // Reserve the widest state so feedback never moves surrounding controls.
                Label(title, systemImage: "doc.on.doc").hidden()
                Label("Copy failed", systemImage: "exclamationmark.circle").hidden()
                HStack(spacing: 5) {
                    Image(systemName: symbol).foregroundStyle(result == .copied ? DeskTheme.status : DeskTheme.text)
                    Text(text)
                }
            }.fixedSize(horizontal: true, vertical: true)
        }
        .buttonStyle(DeskButton())
        .help(feedback)
        .accessibilityLabel(title)
        .accessibilityValue(result == .idle ? "" : feedback)
        .task(id: feedbackID) {
            guard result == .copied else { return }
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            result = .idle
        }
    }
}
