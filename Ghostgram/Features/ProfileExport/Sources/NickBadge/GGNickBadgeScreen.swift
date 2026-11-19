import Foundation
import UIKit
import Display
import SwiftSignalKit
import TelegramCore
import AccountContext
import ItemListUI
import GGCore
import GGSettingsUI

// The nick badge screen: the account's own badge, what a badge costs (from the server, only while
// this screen is open), and the way to the bot. Opened from the menu and from a bulletin's "More".

func ggMakeNickBadgeScreen(context: AccountContext) -> ViewController {
    let accountPeerId = context.account.peerId

    let configSignal: Signal<GGNickBadgeServerConfig?, NoError> = GGNickBadgeSettings.isEnabled.signal
    |> distinctUntilChanged
    |> mapToSignal { _ -> Signal<GGNickBadgeServerConfig?, NoError> in
        return GGNickBadgeService.shared.serverConfig()
    }
    let changes: Signal<Void, NoError> = .single(Void()) |> then(GGNickBadgeService.shared.changes)

    let model = combineLatest(queue: .mainQueue(), GGNickBadgeSettings.isEnabled.signal, configSignal, changes, GGLocalization.shared.languageCodeSignal)
    |> map { isEnabled, _, _, _ -> GGPEScreenModel in
        var model = GGPEScreenModel(title: GGStrings.NickBadge.Screen.title)

        let badge = isEnabled ? GGNickBadgeService.shared.badge(for: accountPeerId) : nil
        let status: String
        if !isEnabled {
            status = GGStrings.NickBadge.Status.off
        } else if let badge = badge {
            status = badge.kind == .team ? GGStrings.NickBadge.Status.team : GGStrings.NickBadge.Status.active
        } else {
            status = GGStrings.NickBadge.Status.none
        }
        let icon = badge.flatMap { GGNickBadgeArt.image(for: $0, height: 28.0) } ?? GGNickBadgeArt.sampleImage(height: 28.0)
        var statusSection: [GGPERow] = [
            GGPERow(id: "statusHeader", kind: .header(GGStrings.NickBadge.Screen.statusHeader)),
            GGPERow(id: "status", kind: .disclosure(title: GGStrings.NickBadge.Screen.status, label: status, icon: GGPEImage(image: icon), enabled: true))
        ]
        if !isEnabled {
            statusSection.append(GGPERow(id: "statusFooter", kind: .footer(GGStrings.NickBadge.Screen.offFooter)))
        }
        model.tap["status"] = {
            if badge != nil {
                ggPresentNickBadgeBulletin(context: context, peerId: accountPeerId)
            }
        }
        model.sections.append(statusSection)

        return model
    }

    return ggPEMakeListController(context: context, model: model)
}


// MARK: - Menu (More › Nick badge)

enum GGNickBadgeMenu {
    static func register() {
        GGMenuRegistry.register(GGMenuRow(
            id: "nickBadge.isEnabled",
            section: .main(of: .moreNickBadge),
            order: 100,
            title: { GGStrings.NickBadge.Menu.show },
            subtitle: { GGStrings.NickBadge.Menu.showInfo },
            kind: .toggle(.global(GGNickBadgeSettings.isEnabled)),
            searchKeywords: { [GGStrings.NickBadge.Menu.keywords] }
        ))
        GGMenuRegistry.register(GGMenuRow(
            id: "nickBadge.screen",
            section: .main(of: .moreNickBadge),
            order: 200,
            title: { GGStrings.NickBadge.Menu.screen },
            subtitle: { GGStrings.NickBadge.Menu.screenInfo },
            icon: .bundle("Chat/Context Menu/Tag"),
            kind: .action({ context in
                context.push(ggMakeNickBadgeScreen(context: context.context))
            }),
            searchKeywords: { [GGStrings.NickBadge.Menu.keywords] }
        ))
    }
}
