import Foundation
import SwiftSignalKit
import GGCore

public struct HoldGramBadgeEntry: Codable, Equatable {
    public let userId: Int64
    public let kind: UInt8 // 0 = supporter, 1 = team, 2 = custom
    public let colorRGB: UInt32
    public let text: String

    public init(userId: Int64, kind: UInt8, colorRGB: UInt32, text: String) {
        self.userId = userId
        self.kind = kind
        self.colorRGB = colorRGB
        self.text = text
    }
}

public final class HoldGramDeveloperStore {
    public static let shared = HoldGramDeveloperStore()
    public static let developerUserId: Int64 = 5033297255

    private let lock = NSLock()
    private var entries: [Int64: HoldGramBadgeEntry] = [:]
    public var onBadgesChanged: (() -> Void)?

    private init() {
        self.load()
    }

    private var storeURL: URL? {
        if let appGroupPath = GGCore.environment?.appGroupPath {
            return URL(fileURLWithPath: appGroupPath).appendingPathComponent("holdgram_dev_badges.json")
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("holdgram_dev_badges.json")
    }

    private func load() {
        self.lock.lock()
        defer { self.lock.unlock() }

        guard let url = self.storeURL, let data = try? Data(contentsOf: url) else {
            return
        }
        if let decoded = try? JSONDecoder().decode([HoldGramBadgeEntry].self, from: data) {
            var map: [Int64: HoldGramBadgeEntry] = [:]
            for entry in decoded {
                map[entry.userId] = entry
            }
            self.entries = map
        }
    }

    private func save() {
        guard let url = self.storeURL else { return }
        let list = Array(self.entries.values)
        if let data = try? JSONEncoder().encode(list) {
            try? data.write(to: url, options: .atomic)
        }
    }

    public func badge(for userId: Int64) -> HoldGramBadgeEntry? {
        self.lock.lock()
        defer { self.lock.unlock() }
        if userId == HoldGramDeveloperStore.developerUserId {
            return HoldGramBadgeEntry(userId: userId, kind: 1, colorRGB: 0x007AFF, text: "HoldGram Developer")
        }
        return self.entries[userId]
    }

    public func grantBadge(userId: Int64, kind: UInt8, colorRGB: UInt32, text: String) {
        self.lock.lock()
        self.entries[userId] = HoldGramBadgeEntry(userId: userId, kind: kind, colorRGB: colorRGB, text: text)
        self.save()
        self.lock.unlock()
        self.onBadgesChanged?()
    }

    public func revokeBadge(userId: Int64) {
        self.lock.lock()
        self.entries.removeValue(forKey: userId)
        self.save()
        self.lock.unlock()
        self.onBadgesChanged?()
    }

    public func allBadges() -> [HoldGramBadgeEntry] {
        self.lock.lock()
        defer { self.lock.unlock() }
        return Array(self.entries.values)
    }
}
