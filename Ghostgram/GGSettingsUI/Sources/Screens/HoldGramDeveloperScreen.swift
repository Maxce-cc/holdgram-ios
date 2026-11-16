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
        header: { "СТАТУС РАЗРАБОТЧИКА" }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "developer.status",
        section: .developerStatus,
        order: 100,
        title: { "HoldGram Developer" },
        subtitle: { "User ID: 5033297255 · Бандл: why.holdgram.wtf · v1.1.0" },
        icon: .bundle("Chat/Context Menu/Restrict"),
        kind: .action({ menuContext in
            let alert = UIAlertController(
                title: "HoldGram Developer",
                message: "Доступ разработчика активен.\n\nUser ID: 5033297255\nBundle ID: why.holdgram.wtf\nВерсия: 1.1.0\nБаза: Telegram iOS 13.1.1",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            menuContext.presentNative(alert)
        }),
        label: { _ in "Активен" }
    ))

    // 2. Badges Management Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .developerBadges,
        screen: .category(.developer),
        order: 200,
        header: { "УПРАВЛЕНИЕ ЗНАЧКАМИ И ГАЛОЧКАМИ" },
        footer: { "Значки отображаются возле имени пользователя в чатах, диалогах и профиле." }
    ))

    // Grant Verified checkmark
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.grantVerified",
        section: .developerBadges,
        order: 100,
        title: { "Выдать синюю галочку (Verified)" },
        subtitle: { "Назначить статус проверенного пользователя" },
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
        title: { "Выдать значок команды (HoldGram Team)" },
        subtitle: { "Значок участника команды разработки" },
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
        title: { "Выдать значок VIP / Supporter" },
        subtitle: { "Золотой значок спонсора проекта" },
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
        title: { "Отозвать значок у пользователя" },
        subtitle: { "Снять выданный статус по User ID" },
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
        title: { "Список выданных значков" },
        subtitle: { "Посмотреть всех пользователей с персональными значками" },
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
        header: { "ОТЛАДКА И ДИАГНОСТИКА" },
        footer: { "Инструменты для отлова багов, выгрузки дампов и системного тестирования." }
    ))

    // Telegram Internal Debug Menu
    GGMenuRegistry.register(GGMenuRow(
        id: "developer.telegramDebug",
        section: .developerDebug,
        order: 100,
        title: { "Внутреннее меню отладки Telegram" },
        subtitle: { "Сброс кэшей базы данных, MTProto, системные переключатели" },
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
        title: { "Поделиться файлами логов" },
        subtitle: { "Экспорт всех файлов журнала (.log) через меню «Поделиться»" },
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
        title: { "Очистить накопленные логи" },
        subtitle: { "Удалить временные лог-файлы с устройства" },
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
        title: "Выдача значка",
        message: "Введите Telegram User ID пользователя, которому хотите выдать значок «\(defaultText)»:",
        preferredStyle: .alert
    )
    alert.addTextField { tf in
        tf.placeholder = "Например, 123456789"
        tf.keyboardType = .numberPad
    }
    alert.addTextField { tf in
        tf.placeholder = "Подпись к значку (необязательно)"
        tf.text = defaultText
    }
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    alert.addAction(UIAlertAction(title: "Выдать", style: .default, handler: { _ in
        guard let idText = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let userId = Int64(idText), userId > 0 else {
            return
        }
        let customText = alert.textFields?[1].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? defaultText
        let textToUse = customText.isEmpty ? defaultText : customText

        HoldGramDeveloperStore.shared.grantBadge(userId: userId, kind: kind, colorRGB: colorRGB, text: textToUse)

        let success = UIAlertController(title: "Успешно", message: "Значок выдан пользователю ID \(userId)!", preferredStyle: .alert)
        success.addAction(UIAlertAction(title: "OK", style: .default))
        menuContext.presentNative(success)
    }))
    menuContext.presentNative(alert)
}

private func ggPromptRevokeBadge(menuContext: GGMenuContext) {
    let alert = UIAlertController(
        title: "Отозвать значок",
        message: "Введите Telegram User ID пользователя для снятия значка:",
        preferredStyle: .alert
    )
    alert.addTextField { tf in
        tf.placeholder = "User ID"
        tf.keyboardType = .numberPad
    }
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    alert.addAction(UIAlertAction(title: "Отозвать", style: .destructive, handler: { _ in
        guard let idText = alert.textFields?[0].text?.trimmingCharacters(in: .whitespacesAndNewlines),
              let userId = Int64(idText) else {
            return
        }
        HoldGramDeveloperStore.shared.revokeBadge(userId: userId)
        let success = UIAlertController(title: "Готово", message: "Значок у пользователя \(userId) отозван.", preferredStyle: .alert)
        success.addAction(UIAlertAction(title: "OK", style: .default))
        menuContext.presentNative(success)
    }))
    menuContext.presentNative(alert)
}

private func ggShowBadgesList(menuContext: GGMenuContext) {
    let badges = HoldGramDeveloperStore.shared.allBadges()
    if badges.isEmpty {
        let alert = UIAlertController(title: "Выданные значки", message: "Пока нет выданных значков другим пользователям.\n(Ваш ID 5033297255 имеет статус Developer постоянно).", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        menuContext.presentNative(alert)
        return
    }

    var text = "Всего выданных значков: \(badges.count)\n\n"
    for b in badges {
        let typeName = (b.kind == 1) ? "Team" : ((b.kind == 2) ? "Verified" : "Supporter")
        text += "• ID: \(b.userId) — [\(typeName)] \"\(b.text)\"\n"
    }

    let alert = UIAlertController(title: "Выданные значки", message: text, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "Закрыть", style: .default))
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
        let alert = UIAlertController(title: "Логи", message: "Файлов логов на данный момент нет.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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

    let alert = UIAlertController(title: "Очистка логов", message: "Удалено файлов журнала: \(removedCount)", preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: "OK", style: .default))
    menuContext.presentNative(alert)
}
