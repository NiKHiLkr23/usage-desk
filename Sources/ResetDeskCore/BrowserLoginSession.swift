import Foundation

public struct BrowserLoginReply: Decodable, Sendable {
    public var loginId: String
    public var authUrl: String
}

public struct BrowserLoginCompletion: Decodable, Sendable {
    public var loginId: String?
    public var success: Bool
    public var error: String?
    public var failureMessage: String {
        let detail = error?.lowercased() ?? ""
        if detail.contains("1455") || detail.contains("address already in use") {
            return "Another Codex sign-in is using the callback port. Finish or cancel it, then retry."
        }
        if detail.contains("state") || detail.contains("expired") {
            return "The sign-in link expired or was replaced. Start sign-in again and use the newest browser tab."
        }
        return "OpenAI sign-in did not complete. Retry with the intended Chrome profile, or choose the default browser."
    }
}

/// Correlates notifications even when completion arrives before the start reply.
/// Authorization URLs stay in memory and never enter saved account metadata.
public struct BrowserLoginSession: Sendable {
    public let attemptID = UUID()
    public private(set) var loginID: String?
    public private(set) var url: URL?
    private var earlyCompletions: [BrowserLoginCompletion] = []
    public init() {}

    public mutating func ready(_ reply: BrowserLoginReply) throws -> BrowserLoginCompletion? {
        let validated = try SignInURL.validated(reply.authUrl)
        loginID = reply.loginId
        url = validated
        defer { earlyCompletions.removeAll() }
        return earlyCompletions.first { $0.loginId == reply.loginId }
    }

    public mutating func receive(_ completion: BrowserLoginCompletion) -> BrowserLoginCompletion? {
        guard completion.loginId != nil else { return nil }
        guard let loginID else { earlyCompletions.append(completion); return nil }
        return completion.loginId == loginID ? completion : nil
    }
}
