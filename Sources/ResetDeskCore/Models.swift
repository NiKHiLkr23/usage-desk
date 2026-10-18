import Foundation

public struct LocalAccount: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var label: String
    public var home: String
    public var managed: Bool
    public var chromeProfile: String?
    public var expectedEmail: String?
    public init(id: String = UUID().uuidString, label: String, home: String, managed: Bool = true, chromeProfile: String? = nil, expectedEmail: String? = nil) {
        self.id = id; self.label = label; self.home = home; self.managed = managed
        self.chromeProfile = chromeProfile; self.expectedEmail = expectedEmail
    }
}

public struct AccountRead: Decodable, Sendable {
    public struct Info: Decodable, Sendable { public var type: String; public var email: String?; public var planType: String? }
    public struct Routing: Decodable, Sendable { public var chatgptAccountId: String }
    public var account: Info?
    public var workspaceRouting: Routing?
}

public struct UsageSnapshot: Decodable, Sendable {
    public struct Window: Decodable, Sendable {
        public var usedPercent: Double
        public var windowDurationMins: Int?
        public var resetsAt: Double?
        public var remaining: Double { min(100, max(0, 100 - usedPercent)) }
        public var resetDate: Date? { resetsAt.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil } }
        public var label: String {
            guard let minutes = windowDurationMins, minutes > 0 else { return "Usage window" }
            if minutes == 10080 { return "Weekly window" }
            if minutes == 1440 { return "Daily window" }
            if minutes % 1440 == 0 { return "\(minutes / 1440)-day window" }
            if minutes % 60 == 0 { return "\(minutes / 60)-hour window" }
            return "\(minutes)-minute window"
        }
    }
    public struct SpendLimit: Decodable, Sendable {
        public var remainingPercent: Double
        public var resetsAt: Double
    }
    public struct Bucket: Decodable, Sendable {
        public var limitId: String?
        public var limitName: String?
        public var primary: Window?
        public var secondary: Window?
        public var individualLimit: SpendLimit?
        public var rateLimitReachedType: String?
    }
    public struct Credit: Decodable, Identifiable, Sendable {
        public var id: String
        public var title: String?
        public var description: String?
        public var status: String
        public var resetType: String
        public var grantedAt: Double
        public var expiresAt: Double?
        public var expiry: Date? { expiresAt.flatMap { $0 > 0 ? Date(timeIntervalSince1970: $0) : nil } }
    }
    public struct Earned: Decodable, Sendable {
        public var availableCount: Int
        public var credits: [Credit]?
    }
    public struct Meter: Identifiable, Sendable {
        public var id: String
        public var bucket: String
        public var label: String
        public var remaining: Double
        public var resetDate: Date?
        public var reached: String?
    }
    public var accountId: String?
    public var ordinaryUsageAllowed: Bool?
    public var rateLimits: Bucket?
    public var rateLimitsByLimitId: [String: Bucket]?
    public var rateLimitResetCredits: Earned?

    public var meters: [Meter] {
        let buckets: [(String, Bucket)]
        if let mapped = rateLimitsByLimitId, !mapped.isEmpty { buckets = mapped.sorted { $0.key < $1.key } }
        else if let bucket = rateLimits { buckets = [(bucket.limitId ?? "codex", bucket)] }
        else { buckets = [] }
        return buckets.flatMap { key, bucket -> [Meter] in
            let name = bucket.limitName ?? (key == "codex" ? "Codex" : key)
            var result = [("primary", bucket.primary), ("secondary", bucket.secondary)].compactMap { slot, window -> Meter? in
                guard let window else { return nil }
                return Meter(id: "\(key):\(slot)", bucket: name, label: window.label, remaining: window.remaining, resetDate: window.resetDate, reached: bucket.rateLimitReachedType)
            }
            if let spend = bucket.individualLimit {
                result.append(Meter(id: "\(key):spend", bucket: name, label: "Spend limit", remaining: min(100, max(0, spend.remainingPercent)), resetDate: Date(timeIntervalSince1970: spend.resetsAt), reached: bucket.rateLimitReachedType))
            }
            return result
        }
    }
}

public enum SignInURL {
    public static func validated(_ string: String) throws -> URL {
        guard let url = URL(string: string), url.scheme == "https", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443,
              let host = url.host?.lowercased(),
              ["auth.openai.com", "auth0.openai.com", "auth.chatgpt.com", "chatgpt.com"].contains(host)
        else { throw DeskError.message("Codex returned an unexpected sign-in address. Update Codex CLI and try again.") }
        return url
    }
}

public enum DeskError: LocalizedError {
    case message(String)
    public var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public struct ChromeProfile: Identifiable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var email: String?
    public var displayName: String { email.map { "\(name) · \($0)" } ?? name }
    public static func parse(localState: Data) throws -> [ChromeProfile] {
        let value = try JSONSerialization.jsonObject(with: localState) as? [String: Any]
        let cache = (value?["profile"] as? [String: Any])?["info_cache"] as? [String: [String: Any]] ?? [:]
        return cache.compactMap { key, row in
            guard !key.isEmpty, key != ".", key != "..", !key.contains("/"), !key.contains("\\"), !key.contains("\0") else { return nil }
            let email = (row["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ChromeProfile(id: key, name: row["name"] as? String ?? key, email: email)
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
}
