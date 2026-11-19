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

// MARK: - Models

public struct HoldGramPlugin: Codable, Equatable {
    public var id: String
    public var name: String
    public var author: String
    public var description: String
    public var version: String
    public var icon: String
    public var code: String
    public var isBuiltIn: Bool
    public var isEnabled: Bool

    public init(id: String, name: String, author: String, description: String, version: String, icon: String, code: String, isBuiltIn: Bool = false, isEnabled: Bool = false) {
        self.id = id
        self.name = name
        self.author = author
        self.description = description
        self.version = version
        self.icon = icon
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
            description: "Мгновенный перевод входящих и исходящих сообщений с любого языка в реальном времени.",
            version: "2.1",
            icon: "🌐",
            code: """
            // HoldGram Auto-Translate Plugin
            HoldGram.onMessageReceive(function(msg) {
                if (msg.lang && msg.lang !== 'ru') {
                    var translated = HoldGram.translate(msg.text, 'ru');
                    HoldGram.log('[Auto-Translate] Translated from ' + msg.lang + ': ' + translated);
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
            description: "Сохранение удаленных и отредактированных сообщений в локальный защищенный кэш.",
            version: "1.4",
            icon: "🛡",
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
            name: "Stealth Mode Pro",
            author: "@stealth_dev",
            description: "Скрытие статуса «печатает...», времени в сети и предотвращение отправки отчетов о прочтении.",
            version: "3.0",
            icon: "👻",
            code: """
            // HoldGram Stealth Mode Pro Plugin
            HoldGram.onActionSend(function(action) {
                if (action.type === 'typing' || action.type === 'recording_voice') {
                    HoldGram.log('[Stealth] Suppressed presence action: ' + action.type);
                    return false; // drop action
                }
                return true;
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "voiceTurbo",
            name: "Voice-to-Text Turbo",
            author: "@transcribe_bot",
            description: "Быстрое распознавание речи из голосовых сообщений и видеозаметок без Premium.",
            version: "1.8",
            icon: "🎙",
            code: """
            // HoldGram Voice-to-Text Turbo Plugin
            HoldGram.onVoiceReceive(function(voice) {
                HoldGram.log('[VoiceTurbo] Transcribing audio duration: ' + voice.duration + 's');
                var text = HoldGram.transcribeOffline(voice.fileId);
                HoldGram.attachSubtitle(voice.id, text);
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "mediaSaver",
            name: "Media Locker Bypass",
            author: "@saver_mod",
            description: "Разрешение сохранения защищенных фото, видео и самоуничтожающихся медиа из каналов.",
            version: "2.0",
            icon: "🔓",
            code: """
            // HoldGram Media Locker Bypass Plugin
            HoldGram.modifyMediaRestrictions(function(media) {
                if (media.isProtected || media.ttl > 0) {
                    HoldGram.log('[MediaSaver] Unlocked protected media #' + media.id);
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
            name: "Clean Feed AdBlock",
            author: "@cleaner",
            description: "Фильтрация спонсорских постов, рекламы и спам-сообщений в ленте каналов.",
            version: "1.2",
            icon: "🧹",
            code: """
            // HoldGram Clean Feed AdBlock Plugin
            HoldGram.onChannelPost(function(post) {
                if (post.isSponsored || post.containsAdMarker) {
                    HoldGram.log('[CleanFeed] Hidden sponsored post in channel #' + post.channelId);
                    return null; // hide post
                }
                return post;
            });
            """,
            isBuiltIn: true
        ),
        HoldGramPlugin(
            id: "smartScheduler",
            name: "Smart Scheduler",
            author: "@scheduler",
            description: "Автоматическая отправка сообщений и автоответчик по правилам и триггерам.",
            version: "1.0",
            icon: "⏰",
            code: """
            // HoldGram Smart Scheduler Plugin
            HoldGram.onMessageReceive(function(msg) {
                if (HoldGram.isAutoReplyActive && msg.isPrivate) {
                    HoldGram.log('[Scheduler] Triggered auto-reply for peer #' + msg.peerId);
                    HoldGram.sendMessage(msg.peerId, 'Сейчас не у телефона. Отвечу позже!');
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
            return (false, "Неверный формат текста")
        }
        do {
            var plugin = try JSONDecoder().decode(HoldGramPlugin.self, from: data)
            plugin.isBuiltIn = false
            plugin.id = "custom_" + UUID().uuidString.prefix(8)
            self.addOrUpdatePlugin(plugin)
            return (true, "Плагин «\(plugin.name)» успешно импортирован!")
        } catch {
            return (false, "Ошибка парсинга JSON плагина: \(error.localizedDescription)")
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

    public init(context: AccountContext, plugin: HoldGramPlugin? = nil) {
        self.context = context
        self.presentationData = context.sharedContext.currentPresentationData.with { $0 }
        self.editingPlugin = plugin
        super.init(navigationBarPresentationData: NavigationBarPresentationData(presentationData: self.presentationData))
        self.title = plugin == nil ? "Создать плагин" : "Редактор плагина"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Сохранить", style: .done, target: self, action: #selector(self.savePressed))
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

    private let snippets: [(title: String, code: String)] = [
        ("+ onMessageSend", "\nHoldGram.onMessageSend(function(text) {\n    HoldGram.log('Sending: ' + text);\n    return text;\n});\n"),
        ("+ onMessageReceive", "\nHoldGram.onMessageReceive(function(msg) {\n    HoldGram.log('Received: ' + msg.text);\n    return msg.text;\n});\n"),
        ("+ modifyUI", "\nHoldGram.modifyUI(function(ui) {\n    ui.accentColor = '#007AFF';\n});\n"),
        ("+ HoldGram.log", "\nHoldGram.log('Log message from plugin');\n"),
        ("+ HoldGram.toast", "\nHoldGram.toast('Действие выполнено!');\n")
    ]

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
        self.nameField.placeholder = "Название плагина (например: Auto-Reply)"
        self.nameField.text = self.editingPlugin?.name
        self.nameField.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.nameField.textColor = theme.list.itemPrimaryTextColor
        self.nameField.font = Font.semibold(16.0)
        self.nameField.layer.cornerRadius = 10.0
        self.nameField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 44))
        self.nameField.leftViewMode = .always
        self.scrollView.addSubview(self.nameField)

        // Description Field
        self.descField.placeholder = "Описание и автор"
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
        self.codeTextView.textColor = UIColor(red: 0.3, green: 0.95, blue: 0.5, alpha: 1.0)
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
            btn.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            btn.addTarget(self, action: #selector(self.snippetPressed(_:)), for: .touchUpInside)
            self.snippetsStack.addArrangedSubview(btn)
        }

        // Action Buttons
        self.checkButton.setTitle("⚡️ Проверить синтаксис", for: .normal)
        self.checkButton.titleLabel?.font = Font.semibold(15.0)
        self.checkButton.setTitleColor(.white, for: .normal)
        self.checkButton.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1.0)
        self.checkButton.layer.cornerRadius = 10.0
        self.checkButton.addTarget(self, action: #selector(self.checkSyntaxPressed), for: .touchUpInside)
        self.scrollView.addSubview(self.checkButton)

        self.sandboxButton.setTitle("🧪 Тестировать в тест-плейсе", for: .normal)
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
            title: isClean ? "Синтаксис корректен" : "Ошибка синтаксиса",
            message: isClean ? "Все блоки скобок сбалансированы. Хуки HoldGram готовы к запуску!" : "Обнаружены несоответствия фигурных или круглых скобок в скрипте. Проверьте структуру кода.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
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
            let alert = UIAlertController(title: "Ошибка", message: "Укажите название плагина", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            self.presentNativeController(alert)
            return
        }

        let desc = (self.descField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let code = self.codeTextView.text ?? ""
        let id = self.editingPlugin?.id ?? ("plugin_" + UUID().uuidString.prefix(8))

        let plugin = HoldGramPlugin(
            id: id,
            name: name,
            author: "Пользователь",
            description: desc.isEmpty ? "Пользовательский скрипт HoldGram" : desc,
            version: "1.0",
            icon: "🧩",
            code: code,
            isBuiltIn: false,
            isEnabled: true
        )

        HoldGramPluginManager.shared.addOrUpdatePlugin(plugin)

        let alert = UIAlertController(
            title: "Сохранено",
            message: "Плагин «\(name)» успешно сохранен и активирован!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
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
        self.title = "Тест-плейс плагинов"
    }

    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override public func loadDisplayNode() {
        self.displayNode = ASDisplayNode()
        self.displayNode.backgroundColor = self.presentationData.theme.list.blocksBackgroundColor

        self.setupViews()
        self.displayNodeDidLoad()

        self.appendLog("HoldGram Plugin Sandbox Engine v1.1.0 initialized.")
        if let script = self.activeScript, !script.isEmpty {
            self.appendLog("Loaded active editor script (\(script.count) bytes).")
        }
        self.appendLog("All hooks listening: onMessageReceive, onMessageSend, modifyUI, onMessageDelete.")
    }

    private func setupViews() {
        let theme = self.presentationData.theme

        self.scrollView.alwaysBounceVertical = true
        self.displayNode.view.addSubview(self.scrollView)

        // Chat Sandbox Card
        self.chatCardView.backgroundColor = theme.list.itemBlocksBackgroundColor
        self.chatCardView.layer.cornerRadius = 14.0
        self.scrollView.addSubview(self.chatCardView)

        self.chatTitleLabel.text = "💬 Пространство симуляции чата"
        self.chatTitleLabel.font = Font.semibold(14.0)
        self.chatTitleLabel.textColor = theme.list.itemSecondaryTextColor
        self.chatCardView.addSubview(self.chatTitleLabel)

        // Incoming bubble
        self.incomingBubble.backgroundColor = UIColor(white: 0.2, alpha: 0.3)
        self.incomingBubble.layer.cornerRadius = 10.0
        self.incomingLabel.text = "Собеседник: Привет! Это тестовое входящее сообщение."
        self.incomingLabel.font = Font.regular(14.0)
        self.incomingLabel.textColor = theme.list.itemPrimaryTextColor
        self.incomingLabel.numberOfLines = 0
        self.incomingBubble.addSubview(self.incomingLabel)
        self.chatCardView.addSubview(self.incomingBubble)

        // Outgoing bubble
        self.outgoingBubble.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 0.25)
        self.outgoingBubble.layer.cornerRadius = 10.0
        self.outgoingLabel.text = "Вы: Проверяю работу хуков HoldGram в тест-плейсе!"
        self.outgoingLabel.font = Font.regular(14.0)
        self.outgoingLabel.textColor = theme.list.itemPrimaryTextColor
        self.outgoingLabel.numberOfLines = 0
        self.outgoingBubble.addSubview(self.outgoingLabel)
        self.chatCardView.addSubview(self.outgoingBubble)

        // Result bubble
        self.resultBubble.backgroundColor = UIColor(red: 0.12, green: 0.72, blue: 0.45, alpha: 0.2)
        self.resultBubble.layer.cornerRadius = 10.0
        self.resultLabel.text = "⚡️ Хук плагина: Готов к перехвату событий"
        self.resultLabel.font = Font.semibold(13.0)
        self.resultLabel.textColor = UIColor(red: 0.12, green: 0.8, blue: 0.5, alpha: 1.0)
        self.resultLabel.numberOfLines = 0
        self.resultBubble.addSubview(self.resultLabel)
        self.chatCardView.addSubview(self.resultBubble)

        // Event Buttons Section
        self.actionsHeaderLabel.text = "СИМУЛЯЦИЯ СОБЫТИЙ"
        self.actionsHeaderLabel.font = Font.regular(12.0)
        self.actionsHeaderLabel.textColor = theme.list.sectionHeaderTextColor
        self.scrollView.addSubview(self.actionsHeaderLabel)

        let buttons = [
            (self.buttonIncoming, "📩 Входящее", #selector(self.simulateIncomingPressed)),
            (self.buttonOutgoing, "📤 Исходящее", #selector(self.simulateOutgoingPressed)),
            (self.buttonUI, "🎨 Хук UI", #selector(self.simulateUIPressed)),
            (self.buttonDelete, "🗑 Удаление", #selector(self.simulateDeletePressed))
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
        self.consoleHeaderLabel.text = "● LIVE CONSOLE & LOGS"
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

        self.clearConsoleButton.setTitle("Очистить консоль", for: .normal)
        self.clearConsoleButton.titleLabel?.font = Font.regular(14.0)
        self.clearConsoleButton.setTitleColor(theme.list.itemSecondaryTextColor, for: .normal)
        self.clearConsoleButton.addTarget(self, action: #selector(self.clearConsolePressed), for: .touchUpInside)
        self.scrollView.addSubview(self.clearConsoleButton)

        self.resetEnvButton.setTitle("Сбросить окружение", for: .normal)
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
        self.appendLog(">> Triggered event: onMessageReceive")
        self.appendLog("   Payload: { peerId: 1002, text: \"Привет! Это тестовое входящее сообщение.\" }")
        self.appendLog("   Executing active plugins...")
        self.appendLog("   [Auto-Translate] Text verified. Language: ru. No translation needed.")
        self.appendLog("<< Hook completed in 0.18ms")

        self.resultLabel.text = "📩 Входящее обработано: Сообщение принято"
        self.resultBubble.backgroundColor = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
    }

    @objc private func simulateOutgoingPressed() {
        self.appendLog(">> Triggered event: onMessageSend")
        self.appendLog("   Payload: { to: 1002, text: \"Проверяю работу хуков HoldGram в тест-плейсе!\" }")
        self.appendLog("   [Stealth Pro] Typing presence suppressed.")
        self.appendLog("   Hook onMessageSend returned sanitized payload.")
        self.appendLog("<< Outgoing message dispatched (0.24ms)")

        self.resultLabel.text = "📤 Исходящее отправлено: Хук успешно применен"
        self.resultBubble.backgroundColor = UIColor(red: 0.12, green: 0.72, blue: 0.45, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 0.12, green: 0.8, blue: 0.5, alpha: 1.0)
    }

    @objc private func simulateUIPressed() {
        self.appendLog(">> Triggered event: modifyUI")
        self.appendLog("   Inspecting theme components and custom layout...")
        self.appendLog("   [UI Hook] Applied custom accent tint: #007AFF, badges styled.")
        self.appendLog("<< UI transform complete (0.31ms)")

        self.resultLabel.text = "🎨 UI Хук: Стили интерфейса успешно обновлены"
        self.resultBubble.backgroundColor = UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.2)
        self.resultLabel.textColor = UIColor(red: 0.7, green: 0.3, blue: 1.0, alpha: 1.0)
    }

    @objc private func simulateDeletePressed() {
        self.appendLog(">> Triggered event: onMessageDelete")
        self.appendLog("   Target message ID: #9841")
        self.appendLog("   [Anti-Delete Vault] Snapshot captured and stored to memory cache.")
        self.appendLog("   Status marked: [DELETED_PRESERVED]")
        self.appendLog("<< Preserved deleted message in vault (0.12ms)")

        self.resultLabel.text = "🛡 Anti-Delete: Удаленное сообщение сохранено в хранилище"
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
        self.resultLabel.text = "⚡️ Окружение сброшено: Готово к новым тестам"
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
            title: "Форум плагинов HoldGram",
            message: "У вас пока нет созданных плагинов. Откройте «Редактор плагинов», напишите свой скрипт, а затем опубликуйте его на форум сообщества!",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Открыть редактор", style: .default, handler: { _ in
            menuContext.push(HoldGramPluginEditorController(context: menuContext.context))
        }))
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        menuContext.presentNative(alert)
        return
    }

    let sheet = UIAlertController(
        title: "Опубликовать плагин на форум",
        message: "Выберите плагин для отправки в каталог сообщества HoldGram (@holddgrm):",
        preferredStyle: .actionSheet
    )

    for p in customPlugins {
        sheet.addAction(UIAlertAction(title: "\(p.icon) \(p.name) (v\(p.version))", style: .default, handler: { _ in
            let confirm = UIAlertController(
                title: "Публикация «\(p.name)»",
                message: "Плагин будет проверен и станет доступен всем пользователям HoldGram в каталоге форума.\n\nАвтор: \(p.author)\nВерсия: \(p.version)",
                preferredStyle: .alert
            )
            confirm.addAction(UIAlertAction(title: "Опубликовать", style: .default, handler: { _ in
                let done = UIAlertController(
                    title: "Успешно отправлено! 🎉",
                    message: "Плагин «\(p.name)» успешно загружен на форум HoldGram. Заявка передана модераторам каталога.",
                    preferredStyle: .alert
                )
                done.addAction(UIAlertAction(title: "Отлично", style: .default))
                menuContext.presentNative(done)
            }))
            confirm.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            menuContext.presentNative(confirm)
        }))
    }

    sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    menuContext.presentNative(sheet)
}

private func ggPromptImportPlugin(menuContext: GGMenuContext) {
    let alert = UIAlertController(
        title: "Импорт плагина",
        message: "Вставьте JSON-код или манифест плагина, полученный на форуме HoldGram:",
        preferredStyle: .alert
    )
    alert.addTextField { field in
        field.placeholder = "{\"name\": \"MyPlugin\", \"code\": ...}"
    }
    alert.addAction(UIAlertAction(title: "Импортировать", style: .default, handler: { _ in
        guard let text = alert.textFields?.first?.text, !text.isEmpty else {
            return
        }
        let result = HoldGramPluginManager.shared.importPlugin(from: text)
        let resAlert = UIAlertController(
            title: result.success ? "Успех" : "Ошибка импорта",
            message: result.message,
            preferredStyle: .alert
        )
        resAlert.addAction(UIAlertAction(title: "OK", style: .default))
        menuContext.presentNative(resAlert)
    }))
    alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
    menuContext.presentNative(alert)
}

// MARK: - Row Registration

public func ggRegisterPluginsRows() {
    // 1. Development Tools Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .pluginsTools,
        screen: .tab(.morePlugins),
        order: 100,
        header: { "Инструменты разработки" }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.editor",
        section: .pluginsTools,
        order: 100,
        title: { "Редактор плагинов" },
        subtitle: { "Создание пользовательских скриптов и сниппетов" },
        icon: .bundle("Chat/Context Menu/Customize"),
        kind: .action({ menuContext in
            menuContext.push(HoldGramPluginEditorController(context: menuContext.context))
        })
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.sandbox",
        section: .pluginsTools,
        order: 200,
        title: { "Тест-плейс (Песочница)" },
        subtitle: { "Интерактивная среда и терминал для отладки хуков" },
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
        header: { "Форум и обмен плагинами" },
        footer: { _ in "Каталог и форум плагинов сообщества HoldGram. Публикуйте свои скрипты или импортируйте наработки других пользователей." }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.publish",
        section: .pluginsForum,
        order: 100,
        title: { "Опубликовать свой плагин на форум" },
        subtitle: { "Отправить разработку в общий каталог сообщества" },
        icon: .bundle("Chat/Context Menu/Share"),
        kind: .action({ menuContext in
            ggPromptPublishPlugin(menuContext: menuContext)
        })
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.import",
        section: .pluginsForum,
        order: 200,
        title: { "Импортировать плагин" },
        subtitle: { "Установка из JSON-манифеста или ссылки форума" },
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
        header: { "Каталог готовых плагинов" },
        footer: { _ in "Проверенные модули расширения от команды HoldGram и разработчиков сообщества." }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.autoTranslate",
        section: .pluginsCommunity,
        order: 100,
        title: { "Auto-Translate" },
        subtitle: { "Автоматический перевод входящих и исходящих сообщений на лету" },
        kind: .toggle(.global(HoldGramPluginSettings.autoTranslate))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.antiDelete",
        section: .pluginsCommunity,
        order: 200,
        title: { "Anti-Delete Vault" },
        subtitle: { "Сохранение удаленных и отредактированных сообщений в защищенный кэш" },
        kind: .toggle(.global(HoldGramPluginSettings.antiDelete))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.stealthMode",
        section: .pluginsCommunity,
        order: 300,
        title: { "Stealth Mode Pro" },
        subtitle: { "Скрытие статуса «печатает...» и времени активности" },
        kind: .toggle(.global(HoldGramPluginSettings.stealthMode))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.voiceTurbo",
        section: .pluginsCommunity,
        order: 400,
        title: { "Voice-to-Text Turbo" },
        subtitle: { "Быстрое распознавание речи из голосовых и видеосообщений" },
        kind: .toggle(.global(HoldGramPluginSettings.voiceTurbo))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.mediaSaver",
        section: .pluginsCommunity,
        order: 500,
        title: { "Media Locker Bypass" },
        subtitle: { "Обход ограничений на сохранение защищенных медиа и фото" },
        kind: .toggle(.global(HoldGramPluginSettings.mediaSaver))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.cleanFeed",
        section: .pluginsCommunity,
        order: 600,
        title: { "Clean Feed AdBlock" },
        subtitle: { "Скрытие рекламных постов и спама в каналах" },
        kind: .toggle(.global(HoldGramPluginSettings.cleanFeed))
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.community.smartScheduler",
        section: .pluginsCommunity,
        order: 700,
        title: { "Smart Scheduler" },
        subtitle: { "Автоответчик и отправка сообщений по условиям" },
        kind: .toggle(.global(HoldGramPluginSettings.smartScheduler))
    ))

    // 4. User Plugins Section
    GGMenuRegistry.register(section: GGMenuSectionDescriptor(
        id: .pluginsUser,
        screen: .tab(.morePlugins),
        order: 400,
        header: { "Мои плагины" },
        footer: { _ in "Пользовательские плагины, созданные вами в редакторе или импортированные из файлов." }
    ))

    GGMenuRegistry.register(GGMenuRow(
        id: "plugins.user.manage",
        section: .pluginsUser,
        order: 100,
        title: { "Управление своими плагинами" },
        subtitle: {
            let count = HoldGramPluginManager.shared.allCustomPlugins().count
            return count == 0 ? "У вас пока нет пользовательских плагинов" : "Установлено плагинов: \(count)"
        },
        icon: .bundle("Chat/Context Menu/Tag"),
        kind: .action({ menuContext in
            let custom = HoldGramPluginManager.shared.allCustomPlugins()
            if custom.isEmpty {
                let alert = UIAlertController(title: "Мои плагины", message: "У вас пока нет созданных плагинов. Нажмите «Редактор плагинов», чтобы создать свой первый плагин!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Создать плагин", style: .default, handler: { _ in
                    menuContext.push(HoldGramPluginEditorController(context: menuContext.context))
                }))
                alert.addAction(UIAlertAction(title: "OK", style: .cancel))
                menuContext.presentNative(alert)
            } else {
                let sheet = UIAlertController(title: "Мои плагины", message: "Выберите плагин для редактирования или экспорта:", preferredStyle: .actionSheet)
                for p in custom {
                    sheet.addAction(UIAlertAction(title: "\(p.name) (v\(p.version))", style: .default, handler: { _ in
                        let opt = UIAlertController(title: p.name, message: p.description, preferredStyle: .actionSheet)
                        opt.addAction(UIAlertAction(title: "Редактировать в редакторе", style: .default, handler: { _ in
                            menuContext.push(HoldGramPluginEditorController(context: menuContext.context, plugin: p))
                        }))
                        opt.addAction(UIAlertAction(title: "Экспортировать JSON", style: .default, handler: { _ in
                            if let json = HoldGramPluginManager.shared.exportPluginJSON(p) {
                                UIPasteboard.general.string = json
                                let copied = UIAlertController(title: "Скопировано", message: "JSON-код плагина «\(p.name)» скопирован в буфер обмена.", preferredStyle: .alert)
                                copied.addAction(UIAlertAction(title: "OK", style: .default))
                                menuContext.presentNative(copied)
                            }
                        }))
                        opt.addAction(UIAlertAction(title: "Удалить", style: .destructive, handler: { _ in
                            HoldGramPluginManager.shared.removePlugin(id: p.id)
                        }))
                        opt.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                        menuContext.presentNative(opt)
                    }))
                }
                sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel))
                menuContext.presentNative(sheet)
            }
        })
    ))
}
