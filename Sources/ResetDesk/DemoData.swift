import Foundation
import ResetDeskCore

extension AccountStore {
    /// Explicit screenshot mode. No storage load, Chrome metadata, timers, or
    /// Codex connections are started, and preferences use a separate domain.
    func populateDemo() {
        accounts = [
            LocalAccount(id: "current", label: "Current Codex account", home: "/demo/current", managed: false),
            LocalAccount(id: "work", label: "Work", home: "/demo/work", expectedEmail: "work@example.com"),
            LocalAccount(id: "lab", label: "Side projects", home: "/demo/lab", expectedEmail: "projects@example.com")
        ]
        selectedID = "current"
        executablePath = "/usr/local/bin/codex"
        launchAtLogin = false
        let now = Date().timeIntervalSince1970
        for (index, account) in accounts.enumerated() {
            let emails = ["personal@example.com", "work@example.com", "projects@example.com"]
            let used = [24, 58, 82][index]
            let read = "{\"account\":{\"type\":\"chatgpt\",\"email\":\"\(emails[index])\",\"planType\":\"plus\"}}"
            let usage = """
            {"rateLimits":{"limitId":"codex","limitName":"Codex",
            "primary":{"usedPercent":\(used),"windowDurationMins":300,"resetsAt":\(now + 8400)},
            "secondary":{"usedPercent":\(12 + index * 20),"windowDurationMins":10080,"resetsAt":\(now + 172800)}},
            "rateLimitResetCredits":{"availableCount":1,"credits":[{"id":"demo-credit","title":"Full reset",
            "description":"Sample earned reset","status":"available","resetType":"codexRateLimits",
            "grantedAt":\(now - 86400),"expiresAt":\(now + 604800)}]}}
            """
            let info = try? JSONDecoder().decode(AccountRead.self, from: Data(read.utf8))
            let snapshot = try? JSONDecoder().decode(UsageSnapshot.self, from: Data(usage.utf8))
            states[account.id] = AccountState(info: info?.account, usage: snapshot, updated: Date())
        }
    }
}
