import Foundation

public struct AccountStorage {
    public let root: URL
    public init(root: URL) { self.root = root }
    public func load() throws -> [LocalAccount] {
        let file = root.appendingPathComponent("accounts.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [] }
        let profiles = try JSONDecoder().decode([LocalAccount].self, from: Data(contentsOf: file))
        guard Set(profiles.map(\.id)).count == profiles.count, !profiles.contains(where: { $0.id == "current" }) else { throw DeskError.message("Account settings contain duplicate identities.") }
        return profiles
    }
    public func save(_ profiles: [LocalAccount]) throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let file = root.appendingPathComponent("accounts.json")
        let data = try JSONEncoder().encode(profiles.filter { $0.id != "current" })
        try data.write(to: file, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }
    public func makeAccount(label: String, chromeProfile: String?, expectedEmail: String?, provider: AccountProvider = .codex) throws -> LocalAccount {
        let id = UUID().uuidString
        let home = root.appendingPathComponent("accounts", isDirectory: true).appendingPathComponent(id, isDirectory: true)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return LocalAccount(id: id, label: label, home: home.path, chromeProfile: chromeProfile, expectedEmail: expectedEmail, provider: provider)
    }
}
