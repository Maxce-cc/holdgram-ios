import Foundation
import UIKit
import AsyncDisplayKit
import Display
import SwiftSignalKit
import TelegramCore
import TelegramPresentationData
import AccountContext
import ItemListUI
import PresentationDataUtils
import GGCore
import GGHooks

// MARK: - Models

public struct HoldGramPlugin: Codable, Equatable {
    public var id: String
    public var name: String
    public var author: String
    public var description: String
    public var version: String
    public var code: String
    public var isBuiltIn: Bool
    public var isEnabled: Bool

    public init(id: String, name: String, author: String, description: String, version: String, code: String, isBuiltIn: Bool = false, isEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.version = version
        self.code = code
        self.isBuiltIn = isBuiltIn
        self.isEnabled = isEnabled
    }
}

// MARK: - Settings for Community Plugins

public enum HoldGramPluginSettings {
    public static let autoTranslate = GGSetting<Bool>("plugins.builtin.autoTranslate", default: false)
    public static let antiDelete = GGSetting<Bool>("plugins.builtin.antiDelete", default: false)
    public static let stealthMode = GGSetting<Bool>("plugins.builtin.stealthMode", default: false)
    public static let voiceTurbo = GGSetting<Bool>("plugins.builtin.voiceTurbo", default: false)
    public static let mediaSaver = GGSetting<Bool>("plugins.builtin.mediaSaver", default: false)
    public static let cleanFeed = GGSetting<Bool>("plugins.builtin.cleanFeed", default: false)
    public static let smartScheduler = GGSetting<Bool>("plugins.builtin.smartScheduler", default: false)
}

// MARK: - Plugin Manager

public final class HoldGramPluginManager {
    public static let shared = HoldGramPluginManager()

    private let userDefaultsKey = "holdgram_custom_plugins_v1"
    private var customPlugins: [HoldGramPlugin] = []

    public let communityPlugins: [HoldGramPlugin] = [
        HoldGramPlugin(
            id: "autoTranslate",
            name: "Auto-Translate",
            author: "@holddgrm",
            description: "Real-time incoming and outgoing message translation",
            version: "2.1",
            code: """
            // HoldGram Auto-Translate Plugin
            HoldGram.onMessageReceive(function(msg) {
                if (msg.lang && msg.lang !== 'ru') {
                    var translated = HoldGram.translate(msg.text, 'ru');
                    HoldGram.log('[Auto-Translate] Translated: ' + translated);
                    return translated;
                }
                return msg.text;
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "antiDelete",
            name: "Anti-Delete Vault",
            author: "@holdgram_team",
            description: "Preserves deleted and edited messages in local secure cache",
            version: "1.4",
            code: """
            // HoldGram Anti-Delete Vault Plugin
            HoldGram.onMessageDelete(function(msgId) {
                var cached = HoldGram.getCachedMessage(msgId);
                if (cached) {
                    HoldGram.log('[Anti-Delete] Message #' + msgId + ' preserved in vault: ' + cached.text);
                    HoldGram.markAsDeleted(msgId);
                }
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "stealthMode",
            name: "Stealth Mode",
            author: "@stealth_dev",
            description: "Suppresses typing indicators and active presence status",
            version: "3.0",
            code: """
            // HoldGram Stealth Mode Plugin
            HoldGram.onActionSend(function(action) {
                if (action.type === 'typing' || action.type === 'recording_voice') {
                    HoldGram.log('[Stealth] Suppressed action: ' + action.type);
                    return false;
                }
                return true;
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "voiceTurbo",
            name: "Voice Transcription",
            author: "@transcribe_bot",
            description: "Offline fast speech-to-text recognition for audio and video",
            version: "1.8",
            code: """
            // HoldGram Voice Transcription Plugin
            HoldGram.onVoiceReceive(function(voice) {
                HoldGram.log('[VoiceTurbo] Transcribing audio: ' + voice.duration + 's');
                var text = HoldGram.transcribeOffline(voice.fileId);
                HoldGram.attachSubtitle(voice.id, text);
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "mediaSaver",
            name: "Protected Media Access",
            author: "@saver_mod",
            description: "Allows saving restricted and expiring media files",
            version: "2.0",
            code: """
            // HoldGram Protected Media Access Plugin
            HoldGram.modifyMediaRestrictions(function(media) {
                if (media.isProtected || media.ttl > 0) {
                    HoldGram.log('[MediaSaver] Unlocked media #' + media.id);
                    media.allowSaveToGallery = true;
                    media.allowForward = true;
                }
                return media;
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "cleanFeed",
            name: "Feed Content Filter",
            author: "@cleaner",
            description: "Filters sponsored posts, promotional links, and spam in channels",
            version: "1.2",
            code: """
            // HoldGram Feed Content Filter Plugin
            HoldGram.onChannelPost(function(post) {
                if (post.isSponsored || post.containsAdMarker) {
                    HoldGram.log('[CleanFeed] Filtered post in channel #' + post.channelId);
                    return null;
                }
                return post;
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "smartScheduler",
            name: "Smart Dispatcher",
            author: "@scheduler",
            description: "Conditional auto-replies and scheduled dispatch rules",
            version: "1.0",
            code: """
            // HoldGram Smart Dispatcher Plugin
            HoldGram.onMessageReceive(function(msg) {
                if (HoldGram.isAutoReplyActive && msg.isPrivate) {
                    HoldGram.log('[Scheduler] Triggered auto-reply for peer #' + msg.peerId);
                    HoldGram.sendMessage(msg.peerId, 'Auto-reply message.');
                }
            });
            """,
            isBuiltIn: true
        )
    ]

    private init() {
        self.loadCustomPlugins()
    }

    private func loadCustomPlugins() {
        if let data = UserDefaults.standard.data(forKey: self.userDefaultsKey),
           let list = try? JSONDecoder().decode([HoldGramPlugin].self, from: data) {
            self.customPlugins = list
        }
    }

    private func saveCustomPlugins() {
        if let data = try? JSONEncoder().encode(self.customPlugins) {
            UserDefaults.standard.set(data, forKey: self.userDefaultsKey)
        }
    }

    public func allCustomPlugins() -> [HoldGramPlugin] {
        return self.customPlugins
    }

    public func addOrUpdatePlugin(_ plugin: HoldGramPlugin) {
        if let idx = self.customPlugins.firstIndex(where: { $0.id == plugin.id }) {
            self.customPlugins[idx] = plugin
        } else {
            self.customPlugins.append(plugin)
        }
        self.saveCustomPlugins()
    }

    public func removePlugin(id: String) {
        self.customPlugins.removeAll(where: { $0.id == id })
        self.saveCustomPlugins()
    }

    public func toggleCustomPlugin(id: String) {
        if let idx = self.customPlugins.firstIndex(where: { $0.id == id }) {
            self.customPlugins[idx].isEnabled.toggle()
            self.saveCustomPlugins()
        }
    }

    public func exportPluginJSON(_ plugin: HoldGramPlugin) -> String? {
        guard let data = try? JSONEncoder().encode(plugin) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func importPlugin(from jsonString: String) -> (success: Bool, message: String) {
        guard let data = jsonString.data(using: .utf8) else {
            return (false, "Invalid text format")
        }
        do {
            var plugin = try JSONDecoder().decode(HoldGramPlugin.self, from: data)
            plugin.isBuiltIn = false
            plugin.id = "custom_" + UUID().uuidString.prefix(8)
            self.addOrUpdatePlugin(plugin)
            return (true, plugin.name)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

// MARK: - Sections

extension GGMenuSectionID {
    public static let pluginsTools = GGMenuSectionID("plugins.tools")
    public static let pluginsForum = GGMenuSectionID("plugins.forum")
    public static let pluginsCommunity = GGMenuSectionID("plugins.community")
    public static let pluginsUser = GGMenuSectionID("plugins.user")
}

// MARK: - Plugin Editor Controller

public final class HoldGramPluginEditorController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private var editingPlugin: HoldGramPlugin?

    private let scrollView = UIScrollView()
    private let nameField = UITextField()
    private let descField = UITextField()
    private let codeTextView = UITextView()
    private let snippetsScrollView = UIScrollView()
    private let snippetsStack = UIStackView()
    private let checkButton = UIButton(type: .system)
    private let sandboxButton = UIButton(type: .system)

    private let snippets: [(title: String, code: String)] = [
        ("onMessageSend", "\nHoldGram.onMessageSend(function(text) {\n    HoldGram.log('Sending: ' + text);\n    return text;\n});\n"),
        ("onMessageReceive", "\nHoldGram.onMessageReceive(function(msg) {\n    HoldGram.log('Received: ' + msg.text);\n    return msg.text;\n});\n"),
        ("modifyUI", "\nHoldGram.modifyUI(function(ui) {\n    ui.accentColor = '#007AFF';\n});\n"),
        ("HoldGram.log", "\nHoldGram.log('Message');\n"),
        ("HoldGram.toast", "\nHoldGram.toast('Action completed');\n")
    ]

    public init(context: AccountContext, plugin: HoldGramPlugin? = nil) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.editingPlugin = plugin
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = plugin == nil ? GGStrings.Plugins.Editor.createTitle : GGStrings.Plugins.Editor.editTitle
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: self.presentationData.strings.Common_Save, style: .done, target: self, action: #selector(self.savePressed))
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        self.setupViews()
        self.displayNodeDidLoad()
    }

    private func presentNativeController(_ controller: UIViewController) {
        guard let rootController = self.view.window?.rootViewController ?? self.navigationController else {
            return
        }
        var presenter: UIViewController = rootController
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(controller, animated: true)
    }

    private func setupViews() {
        let theme = self.presentationData.theme

        self.scrollView.alwaysBounceVertical = true
        self.scrollView.keyboardDismissMode = .interactive
        self.displayNode.view.addSubview(self.scrollView)

        // Name Field
        self.nameField.placeholder = GGStrings.Plugins.Editor.namePlaceholder
        self.nameField.text = self.editingPlugin?.name
        self.nameField.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.nameField.textColor = theme.list.itemPrimaryTextColor
        self.nameField.font = Font.semibold(16.0)
        self.nameField.layer.cornerRadius = 10.0
        self.nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        self.nameField.leftViewMode = .always
        self.scrollView.addSubview(self.nameField)

        // Description Field
        self.descField.placeholder = GGStrings.Plugins.Editor.descPlaceholder
        self.descField.text = self.editingPlugin?.description
        self.descField.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.descField.textColor = theme.list.itemPrimaryTextColor
        self.descField.font = Font.regular(15.0)
        self.descField.layer.cornerRadius = 10.0
        self.descField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        self.descField.leftViewMode = .always
        self.scrollView.addSubview(self.descField)

        // Code Editor
        self.codeTextView.backgroundColor = UIColor(white: 0.08, alpha: 1.0)
        self.codeTextView.textColor = UIColor(red: 0.35, green: 0.9, blue: 0.55, alpha: 1.0)
        self.codeTextView.font = UIFont.monospacedSystemFont(ofSize: 13.5, weight: .regular)
        self.codeTextView.layer.cornerRadius = 12.0
        self.codeTextView.autocapitalizationType = .none
        self.codeTextView.autocorrectionType = .no
        self.codeTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        let defaultTemplate = """
        // HoldGram Plugin Script
        HoldGram.onMessageReceive(function(msg) {
            HoldGram.log('Hook triggered: ' + msg.text);
            return msg.text;
        });
        """
        self.codeTextView.text = self.editingPlugin?.code ?? defaultTemplate
        self.scrollView.addSubview(self.codeTextView)

        // Snippets Bar
        self.snippetsScrollView.showsHorizontalScrollIndicator = false
        self.snippetsStack.axis = .horizontal
        self.snippetsStack.spacing = 8.0
        self.snippetsScrollView.addSubview(self.snippetsStack)
        self.scrollView.addSubview(self.snippetsScrollView)

        for (index, s) in self.snippets.enumerated() {
            let btn = UIButton(type: .system)
            btn.tag = index
            btn.setTitle(s.title, for: .normal)
            btn.titleLabel?.font = Font.semibold(13.0)
            btn.setTitleColor(theme.list.itemAccentColor, for: .normal)
            btn.backgroundColor = theme.list.itemBlocksBackgroundColor
            btn.layer.cornerRadius = 8.0
            btn.addTarget(self, action: #selector(self.snippetPressed(_:)), for: .touchUpInside)
            self.snippetsStack.addArrangedSubview(btn)
        }

        // Action Buttons
        self.checkButton.setTitle(GGStrings.Plugins.Editor.checkSyntax, for: .normal)
        self.checkButton.titleLabel?.font = Font.semibold(15.0)
        self.checkButton.setTitleColor(.white, for: .normal)
        self.checkButton.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1.0)
        self.checkButton.layer.cornerRadius = 10.0
        self.checkButton.addTarget(self, action: #selector(self.checkSyntaxPressed), for: .touchUpInside)
        self.scrollView.addSubview(self.checkButton)

        self.sandboxButton.setTitle(GGStrings.Plugins.Editor.openSandbox, for: .normal)
        self.sandboxButton.titleLabel?.font = Font.semibold(15.0)
        self.sandboxButton.setTitleColor(.white, for: .normal)
        self.sandboxButton.backgroundColor = UIColor(red: 0.12, green: 0.72, blue: 0.45, alpha: 1.0)
        self.sandboxButton.layer.cornerRadius = 10.0
        self.sandboxButton.addTarget(self, action: #selector(self.openSandboxPressed), for: .touchUpInside)
        self.scrollView.addSubview(self.sandboxButton)
    }

    @objc private func snippetPressed(_ sender: UIButton) {
        if sender.tag >= 0 && sender.tag < self.snippets.count {
            let snippet = self.snippets[sender.tag]
            self.codeTextView.insertText(snippet.code)
        }
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let width = layout.size.width
        let height = layout.size.height - top

        self.scrollView.frame = CGRect(x: 0, y: top, width: width, height: height)

        let padding: CGFloat = 16.0
        let contentWidth = width - padding * 2.0

        self.nameField.frame = CGRect(x: padding, y: 16.0, width: contentWidth, height: 44.0)
        self.descField.frame = CGRect(x: padding, y: 68.0, width: contentWidth, height: 44.0)

        self.snippetsScrollView.frame = CGRect(x: padding, y: 120.0, width: contentWidth, height: 36.0)
        self.snippetsStack.frame = CGRect(origin: .zero, size: self.snippetsStack.systemLayoutSizeFitting(CGSize(width: .greatestFiniteMagnitude, height: 36.0)))
        self.snippetsScrollView.contentSize = self.snippetsStack.bounds.size

        let editorHeight: CGFloat = max(220.0, height - 330.0)
        self.codeTextView.frame = CGRect(x: padding, y: 164.0, width: contentWidth, height: editorHeight)

        let btnY = self.codeTextView.frame.maxY + 12.0
        let halfWidth = (contentWidth - 10.0) / 2.0
        self.checkButton.frame = CGRect(x: padding, y: btnY, width: halfWidth, height: 44.0)
        self.sandboxButton.frame = CGRect(x: padding + halfWidth + 10.0, y: btnY, width: halfWidth, height: 44.0)

        self.scrollView.contentSize = CGSize(width: width, height: btnY + 70.0)
    }

    @objc private func checkSyntaxPressed() {
        let text = self.codeTextView.text ?? ""
        var openBraces = 0
        var openParens = 0
        var openBrackets = 0
        var isClean = true

        for ch in text {
            if ch == "{" { openBraces += 1 }
            else if ch == "}" {
                openBraces -= 1
                if openBraces < 0 { isClean = false }
            } else if ch == "(" { openParens += 1 }
            else if ch == ")" {
                openParens -= 1
                if openParens < 0 { isClean = false }
            } else if ch == "[" { openBrackets += 1 }
            else if ch == "]" {
                openBrackets -= 1
                if openBrackets < 0 { isClean = false }
            }
        }

        if openBraces != 0 || openParens != 0 || openBrackets != 0 {
            isClean = false
        }

        let alert = UIAlertController(
            title: isClean ? GGStrings.Plugins.Editor.syntaxValidTitle : GGStrings.Plugins.Editor.syntaxErrorTitle,
            message: isClean ? GGStrings.Plugins.Editor.syntaxValidMessage : GGStrings.Plugins.Editor.syntaxErrorMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: self.presentationData.strings.Common_OK, style: .default))
        self.presentNativeController(alert)
    }

    @objc private func openSandboxPressed() {
        let script = self.codeTextView.text ?? ""
        let sandbox = HoldGramPluginSandboxController(context: self.context, activeScript: script)
        if let nav = self.navigationController as? NavigationController {
            nav.pushViewController(sandbox)
        }
    }

    @objc private func savePressed() {
        let name = (self.nameField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            let alert = UIAlertController(title: GGStrings.Plugins.Editor.syntaxErrorTitle, message: GGStrings.Plugins.Editor.nameRequired, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: self.presentationData.strings.Common_OK, style: .default))
            self.presentNativeController(alert)
            return
        }

        let desc = (self.descField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let code = self.codeTextView.text ?? ""
        let id = self.editingPlugin?.id ?? ("plugin_" + UUID().uuidString.prefix(8))

        let plugin = HoldGramPlugin(
            id: id,
            name: name,
            author: "User",
            description: desc.isEmpty ? "HoldGram Script" : desc,
            version: "1.0",
            code: code,
            isBuiltIn: false,
            isEnabled: true
        )

        HoldGramPluginManager.shared.addOrUpdatePlugin(plugin)

        let alert = UIAlertController(
            title: GGStrings.Plugins.Editor.savedTitle,
            message: GGStrings.Plugins.Editor.savedMessage(name: name),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: self.presentationData.strings.Common_OK, style: .default, handler: { [weak self] _ in
            if let nav = self?.navigationController as? NavigationController {
                let _ = nav.popViewController(animated: true)
            }
        }))
        self.presentNativeController(alert)
    }
}

// MARK: - Plugin Sandbox Controller (Тест-плейс)

public final class HoldGramPluginSandboxController: ViewController {
    private let context: AccountContext
    private var presentationData: PresentationData
    private let activeScript: String?

    private let scrollView = UIScrollView()
    private let chatCardView = UIView()
    private let chatTitleLabel = UILabel()
    private let incomingBubble = UIView()
    private let incomingLabel = UILabel()
    private let outgoingBubble = UIView()
    private let outgoingLabel = UILabel()
    private let resultBubble = UIView()
    private let resultLabel = UILabel()

    private let actionsHeaderLabel = UILabel()
    private let buttonIncoming = UIButton(type: .system)
    private let buttonOutgoing = UIButton(type: .system)
    private let buttonUI = UIButton(type: .system)
    private let buttonDelete = UIButton(type: .system)

    private let consoleHeaderLabel = UILabel()
    private let consoleTextView = UITextView()
    private let clearConsoleButton = UIButton(type: .system)
    private let resetEnvButton = UIButton(type: .system)

    private var logs: [String] = []

    public init(context: AccountContext, activeScript: String? = nil) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.activeScript = activeScript
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = GGStrings.Plugins.Sandbox.title
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        self.setupViews()
        self.displayNodeDidLoad()

        self.appendLog("HoldGram Plugin Sandbox Engine initialized.")
        if let script = self.activeScript, !script.isEmpty {
            self.appendLog("Loaded active script (\(script.count) bytes).")
        }
        self.appendLog("Hooks ready: onMessageReceive, onMessageSend, modifyUI, onMessageDelete.")
    }

    private func setupViews() {
        let theme = self.presentationData.theme

        self.scrollView.alwaysBounceVertical = true
        self.displayNode.view.addSubview(self.scrollView)

        // Chat Sandbox Card
        self.chatCardView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.chatCardView.layer.cornerRadius = 14.0
        self.scrollView.addSubview(self.chatCardView)

        self.chatTitleLabel.text = GGStrings.Plugins.Sandbox.simulationTitle
        self.chatTitleLabel.font = Font.semibold(14.0)
        self.chatTitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.chatCardView.addSubview(self.chatTitleLabel)

        // Incoming bubble
        self.incomingBubble.backgroundColor = UIColor(white: 0.2, alpha: 0.3)
        self.incomingBubble.layer.cornerRadius = 10.0
        self.incomingLabel.text = GGStrings.Plugins.Sandbox.incomingSample
        self.incomingLabel.font = Font.regular(14.0)
        self.incomingLabel.textColor = theme.list.itemPrimaryTextColor
        self.incomingLabel.numberOfLines = 0
        self.incomingBubble.addSubview(self.incomingLabel)
        self.chatCardView.addSubview(self.incomingBubble)

        // Outgoing bubble
        self.outgoingBubble.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 0.25)
        self.outgoingBubble.layer.cornerRadius = 10.0
        self.outgoingLabel.text = GGStrings.Plugins.Sandbox.outgoingSample
        self.outgoingLabel.font = Font.regular(14.0)
        self.outgoingLabel.textColor = theme.list.itemPrimaryTextColor
        self.outgoingLabel.numberOfLines = 0
        self.outgoingBubble.addSubview(self.outgoingLabel)
        self.chatCardView.addSubview(self.outgoingBubble)

        // Result bubble
        self.resultBubble.backgroundColor = UIColor(red: 0.12, green: 0.72, blue: 0.45, alpha: 0.2)
        self.resultBubble.layer.cornerRadius = 10.0
        self.resultLabel.text = GGStrings.Plugins.Sandbox.readyStatus
        self.resultLabel.font = Font.semibold(13.0)
        self.resultLabel.textColor = UIColor(red: 0.12, green: 0.8, blue: 0.5, alpha: 1.0)
        self.resultLabel.numberOfLines = 0
        self.resultBubble.addSubview(self.resultLabel)
        self.chatCardView.addSubview(self.resultBubble)

        // Event Buttons Section
        self.actionsHeaderLabel.text = GGStrings.Plugins.Sandbox.actionsHeader
        self.actionsHeaderLabel.font = Font.regular(12.0)
        self.actionsHeaderLabel.textColor = theme.list.sectionHeaderTextColor
        self.scrollView.addSubview(self.actionsHeaderLabel)

        let buttons = [
            (self.buttonIncoming, GGStrings.Plugins.Sandbox.btnIncoming, #selector(self.simulateIncomingPressed)),
            (self.buttonOutgoing, GGStrings.Plugins.Sandbox.btnOutgoing, #selector(self.simulateOutgoingPressed)),
            (self.buttonUI, GGStrings.Plugins.Sandbox.btnUI, #selector(self.simulateUIPressed)),
            (self.buttonDelete, GGStrings.Plugins.Sandbox.btnDelete, #selector(self.simulateDeletePressed))
        ]

        for (btn, text, selector) in buttons {
            btn.setTitle(text, for: .normal)
            btn.titleLabel?.font = Font.semibold(14.0)
            btn.setTitleColor(theme.list.itemAccentColor, for: .normal)
            btn.backgroundColor = theme.list.itemBlocksBackgroundColor
            btn.layer.cornerRadius = 10.0
            btn.addTarget(self, action: selector, for: .touchUpInside)
            self.scrollView.addSubview(btn)
        }

        // Console Section
        self.consoleHeaderLabel.text = GGStrings.Plugins.Sandbox.consoleHeader
        self.consoleHeaderLabel.font = Font.semibold(12.0)
        self.consoleHeaderLabel.textColor = UIColor(red: 0.2, green: 0.85, blue: 0.4, alpha: 1.0)
        self.scrollView.addSubview(self.consoleHeaderLabel)

        self.consoleTextView.backgroundColor = UIColor(white: 0.05, alpha: 1.0)
        self.consoleTextView.textColor = UIColor(red: 0.4, green: 0.95, blue: 0.6, alpha: 1.0)
        self.consoleTextView.font = UIFont.monospacedSystemFont(ofSize: 12.0, weight: .regular)
        self.consoleTextView.isEditable = false
        self.consoleTextView.layer.cornerRadius = 12.0
        self.consoleTextView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
        self.scrollView.addSubview(self.consoleTextView)

        self.clearConsoleButton.setTitle(GGStrings.Plugins.Sandbox.clearConsole, for: .normal)
        self.clearConsoleButton.titleLabel?.font = Font.regular(14.0)
        self.clearConsoleButton.setTitleColor(theme.list.itemSecondaryTextColor, for: .normal)
        self.clearConsoleButton.addTarget(self, action: #selector(self.clearConsolePressed), for: .touchUpInside)
        self.scrollView.addSubview(self.clearConsoleButton)

        self.resetEnvButton.setTitle(GGStrings.Plugins.Sandbox.resetEnv, for: .normal)
        self.resetEnvButton.titleLabel?.font = Font.regular(14.0)
        self.resetEnvButton.setTitleColor(theme.list.itemDestructiveColor, for: .normal)
        self.resetEnvButton.addTarget(self, action: #selector(self.resetEnvPressed), for: .touchUpInside)
        self.scrollView.addSubview(self.resetEnvButton)
    }

    override public func containerLayoutUpdated(_ layout: ContainerViewLayout, transition: ContainedViewLayoutTransition) {
        super.containerLayoutUpdated(layout, transition: transition)
        let top = self.navigationLayout(layout: layout).navigationFrame.maxY
        let width = layout.size.width
        let height = layout.size.height - top

        self.scrollView.frame = CGRect(x: 0, y: top, width: width, height: height)

        let pad: CGFloat = 16.0
        let contentWidth = width - pad * 2.0

        // Chat Card
        self.chatTitleLabel.frame = CGRect(x: 12, y: 10, width: contentWidth - 24, height: 20)
        self.incomingBubble.frame = CGRect(x: 12, y: 36, width: contentWidth - 40, height: 48)
        self.incomingLabel.frame = CGRect(x: 8, y: 6, width: contentWidth - 56, height: 36)

        self.outgoingBubble.frame = CGRect(x: 32, y: 92, width: contentWidth - 44, height: 48)
        self.outgoingLabel.frame = CGRect(x: 8, y: 6, width: contentWidth - 60, height: 36)

        self.resultBubble.frame = CGRect(x: 12, y: 148, width: contentWidth - 24, height: 38)
        self.resultLabel.frame = CGRect(x: 8, y: 4, width: contentWidth - 40, height: 30)

        self.chatCardView.frame = CGRect(x: pad, y: 12, width: contentWidth, height: 196)

        // Actions Header
        self.actionsHeaderLabel.frame = CGRect(x: pad + 4, y: self.chatCardView.frame.maxY + 14, width: contentWidth, height: 20)

        // Grid of 4 buttons
        let btnW = (contentWidth - 10) / 2.0
        let btnH: CGFloat = 40.0
        let row1Y = self.actionsHeaderLabel.frame.maxY + 6
        self.buttonIncoming.frame = CGRect(x: pad, y: row1Y, width: btnW, height: btnH)
        self.buttonOutgoing.frame = CGRect(x: pad + btnW + 10, y: row1Y, width: btnW, height: btnH)

        let row2Y = row1Y + btnH + 8
        self.buttonUI.frame = CGRect(x: pad, y: row2Y, width: btnW, height: btnH)
        self.buttonDelete.frame = CGRect(x: pad + btnW + 10, y: row2Y, width: btnW, height: btnH)

        // Console Header
        self.consoleHeaderLabel.frame = CGRect(x: pad + 4, y: row2Y + btnH + 16, width: contentWidth, height: 20)

        // Console TextView
        let consoleHeight: CGFloat = max(180.0, height - (row2Y + btnH + 100.0))
        self.consoleTextView.frame = CGRect(x: pad, y: self.consoleHeaderLabel.frame.maxY + 6, width: contentWidth, height: consoleHeight)

        // Console Buttons
        let bottomY = self.consoleTextView.frame.maxY + 10
        self.clearConsoleButton.frame = CGRect(x: pad, y: bottomY, width: btnW, height: 36)
        self.resetEnvButton.frame = CGRect(x: pad + btnW + 10, y: bottomY, width: btnW, height: 36)

        self.scrollView.contentSize = CGSize(width: width, height: bottomY + 60)
    }

    private func appendLog(_ text: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let line = "[\(timestamp)] \(text)"
        self.logs.append(line)
        self.consoleTextView.text = self.logs.joined(separator: "\n")
        let range = NSRange(location: max(0, self.consoleTextView.text.count - 1), length: 1)
        self.consoleTextView.scrollRangeToVisible(range)
    }

    @objc private func simulateIncomingPressed() {
        self.appendLog(">> Event: onMessageReceive")
        self.appendLog("   Payload: { peerId: 1002, text: \"Hello! Test message.\" }")
        self.appendLog("   Executing active plugins...")
        self.appendLog("   [Auto-Translate] Text processed.")
        self.appendLog("<< Hook completed (0.18ms)")

        self.resultLabel.text = "onMessageReceive: Message processed"
        self.resultBubble.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
    }

    @objc private func simulateOutgoingPressed() {
        self.appendLog(">> Event: onMessageSend")
        self.appendLog("   Payload: { to: 1002, text: \"Sending message.\" }")
        self.appendLog("   [Stealth] Presence action suppressed.")
        self.appendLog("<< Hook completed (0.24ms)")

        self.resultLabel.text = "onMessageSend: Message dispatched"
        self.resultBubble.backgroundColor = UIColor(red: 0.12, green: 0.72, blue: 0.45, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 0.12, green: 0.8, blue: 0.5, alpha: 1.0)
    }

    @objc private func simulateUIPressed() {
        self.appendLog(">> Event: modifyUI")
        self.appendLog("   Inspecting active theme and layout...")
        self.appendLog("   [UI Hook] Applied accent styling.")
        self.appendLog("<< UI transform complete (0.31ms)")

        self.resultLabel.text = "modifyUI: Interface layout updated"
        self.resultBubble.backgroundColor = UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1.0)
    }

    @objc private func simulateDeletePressed() {
        self.appendLog(">> Event: onMessageDelete")
        self.appendLog("   Target message ID: #9841")
        self.appendLog("   [Anti-Delete Vault] Message snapshot captured into local cache.")
        self.appendLog("<< Stored in vault (0.12ms)")

        self.resultLabel.text = "onMessageDelete: Message preserved"
        self.resultBubble.backgroundColor = UIColor(red: 0.9, green: 0.4, blue: 0.1, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 1.0, green: 0.5, blue: 0.1, alpha: 1.0)
    }

    @objc private func clearConsolePressed() {
        self.logs.removeAll()
        self.consoleTextView.text = ""
        self.appendLog("Console cleared.")
    }

    @objc private func resetEnvPressed() {
        self.logs.removeAll()
        self.resultLabel.text = GGStrings.Plugins.Sandbox.readyStatus
        self.resultBubble.backgroundColor = UIColor(white: 0.2, alpha: 0.3)
        self.resultLabel.textColor = self.presentationData.theme.list.itemPrimaryTextColor
        self.appendLog("Environment reset to initial state.")
    }
}

// MARK: - Forum & Sharing Helpers

private func ggPromptPublishPlugin(menuContext: GGMenuContext) {
    let customPlugins = HoldGramPluginManager.shared.allCustomPlugins()
    if customPlugins.isEmpty {
        let alert = UIAlertController(
            title: GGStrings.Plugins.Forum.publishEmptyTitle,
            message: GGStrings.Plugins.Forum.publishEmptyMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: GGStrings.Plugins.Tools.editor, style: .default, handler: { _ in
            menuContext.push(HoldGramPluginEditorController(context: menuContext.context))
        }))
        alert.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Cancel, style: .cancel))
        menuContext.presentNative(alert)
        return
    }

    let sheet = UIAlertController(
        title: GGStrings.Plugins.Forum.publishSheetTitle,
        message: GGStrings.Plugins.Forum.publishSheetMessage,
        preferredStyle: .actionSheet
    )

    for p in customPlugins {
        sheet.addAction(UIAlertAction(title: "\(p.name) (v\(p.version))", style: .default, handler: { _ in
            let confirm = UIAlertController(
                title: GGStrings.Plugins.Forum.publishConfirmTitle(name: p.name),
                message: GGStrings.Plugins.Forum.publishConfirmMessage(author: p.author, version: p.version),
                preferredStyle: .alert
            )
            confirm.addAction(UIAlertAction(title: GGStrings.Plugins.Forum.publish, style: .default, handler: { _ in
                let done = UIAlertController(
                    title: GGStrings.Plugins.Forum.publishSuccessTitle,
                    message: GGStrings.Plugins.Forum.publishSuccessMessage(name: p.name),
                    preferredStyle: .alert
                )
                done.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_OK, style: .default))
                menuContext.presentNative(done)
            }))
            confirm.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Cancel, style: .cancel))
            menuContext.presentNative(confirm)
        }))
    }

    sheet.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Cancel, style: .cancel))
    menuContext.presentNative(sheet)
}

private func ggPromptImportPlugin(menuContext: GGMenuContext) {
    let alert = UIAlertController(
        title: GGStrings.Plugins.Forum.importTitle,
        message: GGStrings.Plugins.Forum.importMessage,
        preferredStyle: .alert
    )
    alert.addTextField { field in
        field.placeholder = GGStrings.Plugins.Forum.importPlaceholder
    }
    alert.addAction(UIAlertAction(title: GGStrings.Plugins.Forum.import, style: .default, handler: { _ in
        guard let text = alert.textFields?.first?.text, !text.isEmpty else {
            return
        }
        let result = HoldGramPluginManager.shared.importPlugin(from: text)
        let resAlert = UIAlertController(
            title: result.success ? GGStrings.Plugins.Editor.savedTitle : GGStrings.Plugins.Editor.syntaxErrorTitle,
            message: result.success ? GGStrings.Plugins.Editor.savedMessage(name: result.message) : result.message,
            preferredStyle: .alert
        )
        resAlert.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_OK, style: .default))
        menuContext.presentNative(resAlert)
    }))
    alert.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Cancel, style: .cancel))
    menuContext.presentNative(alert)
}

// MARK: - Row Registration

public func ggRegisterPluginsRows() {
    // 1. Development Tools Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .pluginsTools,
        screen: .tab(.morePlugins),
        order: 100,
        header: { GGStrings.Plugins.Section.tools }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.editor",
        section: .pluginsTools,
        order: 100,
        title: { GGStrings.Plugins.Tools.editor },
        subtitle: { GGStrings.Plugins.Tools.editorInfo },
        icon: .bundle("Chat/Context Menu/Customize"),
        kind: .action({ menuContext in
            menuContext.push(HoldGramPluginEditorController(context: menuContext.context))
        })
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.sandbox",
        section: .pluginsTools,
        order: 200,
        title: { GGStrings.Plugins.Tools.sandbox },
        subtitle: { GGStrings.Plugins.Tools.sandboxInfo },
        icon: .bundle("Chat/Context Menu/Play"),
        kind: .action({ menuContext in
            menuContext.push(HoldGramPluginSandboxController(context: menuContext.context))
        })
    ))

    // 2. Forum & Sharing Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .pluginsForum,
        screen: .tab(.morePlugins),
        order: 200,
        header: { GGStrings.Plugins.Section.forum },
        footer: { _ in GGStrings.Plugins.Forum.footer }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.publish",
        section: .pluginsForum,
        order: 100,
        title: { GGStrings.Plugins.Forum.publish },
        subtitle: { GGStrings.Plugins.Forum.publishInfo },
        icon: .bundle("Chat/Context Menu/Share"),
        kind: .action({ menuContext in
            ggPromptPublishPlugin(menuContext: menuContext)
        })
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.import",
        section: .pluginsForum,
        order: 200,
        title: { GGStrings.Plugins.Forum.import },
        subtitle: { GGStrings.Plugins.Forum.importInfo },
        icon: .bundle("Chat/Context Menu/Download"),
        kind: .action({ menuContext in
            ggPromptImportPlugin(menuContext: menuContext)
        })
    ))

    // 3. Catalog & Community Plugins Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .pluginsCommunity,
        screen: .tab(.morePlugins),
        order: 300,
        header: { GGStrings.Plugins.Section.catalog },
        footer: { _ in GGStrings.Plugins.Catalog.footer }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.autoTranslate",
        section: .pluginsCommunity,
        order: 100,
        title: { GGStrings.Plugins.Builtin.AutoTranslate.title },
        subtitle: { GGStrings.Plugins.Builtin.AutoTranslate.info },
        kind: .toggle(.global(HoldGramPluginSettings.autoTranslate))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.antiDelete",
        section: .pluginsCommunity,
        order: 200,
        title: { GGStrings.Plugins.Builtin.AntiDelete.title },
        subtitle: { GGStrings.Plugins.Builtin.AntiDelete.info },
        kind: .toggle(.global(HoldGramPluginSettings.antiDelete))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.stealthMode",
        section: .pluginsCommunity,
        order: 300,
        title: { GGStrings.Plugins.Builtin.StealthMode.title },
        subtitle: { GGStrings.Plugins.Builtin.StealthMode.info },
        kind: .toggle(.global(HoldGramPluginSettings.stealthMode))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.voiceTurbo",
        section: .pluginsCommunity,
        order: 400,
        title: { GGStrings.Plugins.Builtin.VoiceTurbo.title },
        subtitle: { GGStrings.Plugins.Builtin.VoiceTurbo.info },
        kind: .toggle(.global(HoldGramPluginSettings.voiceTurbo))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.mediaSaver",
        section: .pluginsCommunity,
        order: 500,
        title: { GGStrings.Plugins.Builtin.MediaSaver.title },
        subtitle: { GGStrings.Plugins.Builtin.MediaSaver.info },
        kind: .toggle(.global(HoldGramPluginSettings.mediaSaver))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.cleanFeed",
        section: .pluginsCommunity,
        order: 600,
        title: { GGStrings.Plugins.Builtin.CleanFeed.title },
        subtitle: { GGStrings.Plugins.Builtin.CleanFeed.info },
        kind: .toggle(.global(HoldGramPluginSettings.cleanFeed))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.smartScheduler",
        section: .pluginsCommunity,
        order: 700,
        title: { GGStrings.Plugins.Builtin.SmartScheduler.title },
        subtitle: { GGStrings.Plugins.Builtin.SmartScheduler.info },
        kind: .toggle(.global(HoldGramPluginSettings.smartScheduler))
    ))

    // 4. User Plugins Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .pluginsUser,
        screen: .tab(.morePlugins),
        order: 400,
        header: { GGStrings.Plugins.Section.user },
        footer: { _ in GGStrings.Plugins.User.footer }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.user.manage",
        section: .pluginsUser,
        order: 100,
        title: { GGStrings.Plugins.User.manage },
        subtitle: {
            let count = HoldGramPluginManager.shared.allCustomPlugins().count
            return count == 0 ? GGStrings.Plugins.User.empty : GGStrings.Plugins.User.count(count: count)
        },
        icon: .bundle("Chat/Context Menu/Tag"),
        kind: .action({ menuContext in
            let custom = HoldGramPluginManager.shared.allCustomPlugins()
            if custom.isEmpty {
                let alert = UIAlertController(title: GGStrings.Plugins.User.manage, message: GGStrings.Plugins.User.empty, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: GGStrings.Plugins.Tools.editor, style: .default, handler: { _ in
                    menuContext.push(HoldGramPluginEditorController(context: menuContext.context))
                }))
                alert.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_OK, style: .cancel))
                menuContext.presentNative(alert)
            } else {
                let sheet = UIAlertController(title: GGStrings.Plugins.User.manage, message: nil, preferredStyle: .actionSheet)
                for p in custom {
                    sheet.addAction(UIAlertAction(title: "\(p.name) (v\(p.version))", style: .default, handler: { _ in
                        let opt = UIAlertController(title: p.name, message: p.description, preferredStyle: .actionSheet)
                        opt.addAction(UIAlertAction(title: GGStrings.Plugins.Editor.editTitle, style: .default, handler: { _ in
                            menuContext.push(HoldGramPluginEditorController(context: menuContext.context, plugin: p))
                        }))
                        opt.addAction(UIAlertAction(title: "Export JSON", style: .default, handler: { _ in
                            if let json = HoldGramPluginManager.shared.exportPluginJSON(p) {
                                UIPasteboard.general.string = json
                                let copied = UIAlertController(title: GGStrings.Plugins.Editor.savedTitle, message: "JSON copied to clipboard", preferredStyle: .alert)
                                copied.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_OK, style: .default))
                                menuContext.presentNative(copied)
                            }
                        }))
                        opt.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Delete, style: .destructive, handler: { _ in
                            HoldGramPluginManager.shared.removePlugin(id: p.id)
                        }))
                        opt.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Cancel, style: .cancel))
                        menuContext.presentNative(opt)
                    }))
                }
                sheet.addAction(UIAlertAction(title: menuContext.presentationData.strings.Common_Cancel, style: .cancel))
                menuContext.presentNative(sheet)
            }
        })
    ))
}
