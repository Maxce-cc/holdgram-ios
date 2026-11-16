import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import PresentationDataUtils
import GGCore
import GGHooks

extension GGMenuSectionID {
    public static let developerStatus = GGMenuSectionID("developer.status")
    public static let developerBadges = GGMenuSectionID("developer.badges")
    public static let developerDebug = GGMenuSectionID("developer.debug")
}

func ggRegisterDeveloperRows() {
    // 1. Status Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .developerStatus,
        screen: .category(.developer),
        order: 100,
        header: { GGStrings.Developer.Status.header }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "developer.status",
        section: .developerStatus,
        order: 100,
        title: { GGStrings.Developer.Status.title },
        subtitle: { GGStrings.Developer.Status.subtitle(userId: "5033297255", bundleId: "why.holdgram.wtf", version: "1.1.0") },
        icon: .bundle("Chat/Context Menu/Restrict"),
        kind: .action({ menuContext in
            let alert = UIAlertController(
                title: GGStrings.Developer.Status.alertTitle,
                message: GGStrings.Developer.Status.alertMessage(userId: "5033297255", bundleId: "why.holdgram.wtf", version: "1.1.0"),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.ok, style: .default))
            menuContext.presentNative(alert)
        }),
        label: { _ in GGStrings.Developer.Status.active }
    ))

    // 2. Badges Management Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .developerBadges,
        screen: .category(.developer),
        order: 200,
        header: { GGStrings.Developer.Badges.header },
        footer: { GGStrings.Developer.Badges.footer }
    ))

    // Grant Verified checkmark
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.grantVerified",
        section: .developerBadges,
        order: 100,
        title: { GGStrings.Developer.Badges.grantVerified },
        subtitle: { GGStrings.Developer.Badges.grantVerifiedSubtitle },
        icon: .bundle("Chat/Context Menu/Select"),
        kind: .action({ menuContext in
            ggPromptGrantBadge(menuContext: menuContext, kind: 2, colorRGB: 0x007AFF, defaultText: "HoldGram Verified")
        })
    ))

    // Grant Team / Dev badge
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.grantTeam",
        section: .developerBadges,
        order: 200,
        title: { GGStrings.Developer.Badges.grantTeam },
        subtitle: { GGStrings.Developer.Badges.grantTeamSubtitle },
        icon: .bundle("Chat/Context Menu/Tag"),
        kind: .action({ menuContext in
            ggPromptGrantBadge(menuContext: menuContext, kind: 1, colorRGB: 0xFE2C55, defaultText: "HoldGram Team")
        })
    ))

    // Grant Supporter VIP badge
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.grantSupporter",
        section: .developerBadges,
        order: 300,
        title: { GGStrings.Developer.Badges.grantSupporter },
        subtitle: { GGStrings.Developer.Badges.grantSupporterSubtitle },
        icon: .bundle("Chat/Context Menu/Pin"),
        kind: .action({ menuContext in
            ggPromptGrantBadge(menuContext: menuContext, kind: 0, colorRGB: 0xFFD700, defaultText: "HoldGram Supporter")
        })
    ))

    // Revoke badge
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.revokeBadge",
        section: .developerBadges,
        order: 400,
        title: { GGStrings.Developer.Badges.revokeBadge },
        subtitle: { GGStrings.Developer.Badges.revokeBadgeSubtitle },
        icon: .bundle("Chat/Context Menu/Clear"),
        kind: .action({ menuContext in
            ggPromptRevokeBadge(menuContext: menuContext)
        }),
        isDestructive: true
    ))

    // Badges count / list
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.badgesList",
        section: .developerBadges,
        order: 500,
        title: { GGStrings.Developer.Badges.badgesList },
        subtitle: { GGStrings.Developer.Badges.badgesListSubtitle },
        icon: .bundle("Chat/Context Menu/List"),
        kind: .action({ menuContext in
            ggShowBadgesList(menuContext: menuContext)
        }),
        label: { _ in
            let count = HoldGramDeveloperStore.shared.allBadges().count
            return "\(count)"
        }
    ))

    // 3. Debugging & Logs Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .developerDebug,
        screen: .category(.developer),
        order: 300,
        header: { GGStrings.Developer.Debug.header },
        footer: { GGStrings.Developer.Debug.footer }
    ))

    // Telegram Internal Debug Menu
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.telegramDebug",
        section: .developerDebug,
        order: 100,
        title: { GGStrings.Developer.Debug.telegramDebug },
        subtitle: { GGStrings.Developer.Debug.telegramDebugSubtitle },
        icon: .bundle("Chat/Context Menu/Settings"),
        kind: .action({ menuContext in
            if let controller = GGSettingsUIEnvironment.shared.makeDebugController?(menuContext.context) {
                menuContext.push(controller)
            }
        }),
        isVisible: { _ in
            return GGSettingsUIEnvironment.shared.makeDebugController != nil
        }
    ))

    // Export Logs
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.shareLogs",
        section: .developerDebug,
        order: 200,
        title: { GGStrings.Developer.Debug.shareLogs },
        subtitle: { GGStrings.Developer.Debug.shareLogsSubtitle },
        icon: .bundle("Chat/Context Menu/Share"),
        kind: .action({ menuContext in
            ggShareAppLogs(menuContext: menuContext)
        })
    ))

    // Clear Logs
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.clearLogs",
        section: .developerDebug,
        order: 300,
        title: { GGStrings.Developer.Debug.clearLogs },
        subtitle: { GGStrings.Developer.Debug.clearLogsSubtitle },
        icon: .bundle("Chat/Context Menu/Delete"),
        kind: .action({ menuContext in
            ggClearAppLogs(menuContext: menuContext)
        }),
        isDestructive: true
    ))
}

// MARK: - Helper Prompts & Actions

private func ggPromptGrantBadge(menuContext: GGMenuContext, kind: UInt8, colorRGB: UInt32, defaultText: String) {
    let alert = UIAlertController(
        title: GGStrings.Developer.Action.grantBadgeTitle,
        message: GGStrings.Developer.Action.grantBadgeMessage(badge: defaultText),
        preferredStyle: .alert
    )
    alert.addTextField { tf in
        tf.placeholder = GGStrings.Developer.Action.grantBadgePlaceholderId
        tf.keyboardType = .numberPad
    }
    alert.addTextField { tf in
        tf.placeholder = GGStrings.Developer.Action.grantBadgePlaceholderText
        tf.text = defaultText
    }
    alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.cancel, style: .cancel))
    alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.grant, style: .default, handler: { _ in
        guard let idText = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let userId = Int64(idText), userId > 0 else {
            return
        }
        let customText = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? defaultText
        let textToUse = customText.isEmpty ? defaultText : customText

        HoldGramDeveloperStore.shared.grantBadge(userId: userId, kind: kind, colorRGB: colorRGB, text: textToUse)

        let success = UIAlertController(title: GGStrings.Developer.Action.success, message: GGStrings.Developer.Action.grantSuccess(userId: "\(userId)"), preferredStyle: .alert)
        success.addAction(UIAlertAction(title: GGStrings.Developer.Action.ok, style: .default))
        menuContext.presentNative(success)
    }))
    menuContext.presentNative(alert)
}

private func ggPromptRevokeBadge(menuContext: GGMenuContext) {
    let alert = UIAlertController(
        title: GGStrings.Developer.Action.revokeBadgeTitle,
        message: GGStrings.Developer.Action.revokeBadgeMessage,
        preferredStyle: .alert
    )
    alert.addTextField { tf in
        tf.placeholder = GGStrings.Developer.Action.revokeBadgePlaceholderId
        tf.keyboardType = .numberPad
    }
    alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.cancel, style: .cancel))
    alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.revoke, style: .destructive, handler: { _ in
        guard let idText = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let userId = Int64(idText) else {
            return
        }
        HoldGramDeveloperStore.shared.revokeBadge(userId: userId)
        let success = UIAlertController(title: GGStrings.Developer.Action.done, message: GGStrings.Developer.Action.revokeSuccess(userId: "\(userId)"), preferredStyle: .alert)
        success.addAction(UIAlertAction(title: GGStrings.Developer.Action.ok, style: .default))
        menuContext.presentNative(success)
    }))
    menuContext.presentNative(alert)
}

private func ggShowBadgesList(menuContext: GGMenuContext) {
    let badges = HoldGramDeveloperStore.shared.allBadges()
    if badges.isEmpty {
        let alert = UIAlertController(title: GGStrings.Developer.Action.badgesListTitle, message: GGStrings.Developer.Action.badgesListEmpty(userId: "5033297255"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.ok, style: .default))
        menuContext.presentNative(alert)
        return
    }

    var text = GGStrings.Developer.Action.badgesListTotal(count: badges.count)
    for b in badges {
        let typeName = (b.kind == 1) ? "Team" : ((b.kind == 2) ? "Verified" : "Supporter")
        text += "• ID: \(b.userId) — [\(typeName)] \"\(b.text)\"\n"
    }

    let alert = UIAlertController(title: GGStrings.Developer.Action.badgesListTitle, message: text, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.close, style: .default))
    menuContext.presentNative(alert)
}

private func ggShareAppLogs(menuContext: GGMenuContext) {
    var logURLs: [URL] = []
    let fm = FileManager.default
    if let appGroupPath = GGCore.environment?.appGroupPath {
        let logsPath = (appGroupPath as NSString).appendingPathComponent("logs")
        if let files = try? fm.contentsOfDirectory(atPath: logsPath) {
            for file in files where file.hasSuffix(".log") {
                logURLs.append(URL(fileURLWithPath: (logsPath as NSString).appendingPathComponent(file)))
            }
        }
    }

    if logURLs.isEmpty {
        let alert = UIAlertController(title: GGStrings.Developer.Action.logsTitle, message: GGStrings.Developer.Action.logsEmpty, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.ok, style: .default))
        menuContext.presentNative(alert)
        return
    }

    let activity = UIActivityViewController(activityItems: logURLs, applicationActivities: nil)
    menuContext.presentNative(activity)
}

private func ggClearAppLogs(menuContext: GGMenuContext) {
    let fm = FileManager.default
    var removedCount = 0
    if let appGroupPath = GGCore.environment?.appGroupPath {
        let logsPath = (appGroupPath as NSString).appendingPathComponent("logs")
        if let files = try? fm.contentsOfDirectory(atPath: logsPath) {
            for file in files where file.hasSuffix(".log") {
                try? fm.removeItem(atPath: (logsPath as NSString).appendingPathComponent(file))
                removedCount += 1
            }
        }
    }

    let alert = UIAlertController(title: GGStrings.Developer.Action.logsClearTitle, message: GGStrings.Developer.Action.logsCleared(count: removedCount), preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: GGStrings.Developer.Action.ok, style: .default))
    menuContext.presentNative(alert)
}
