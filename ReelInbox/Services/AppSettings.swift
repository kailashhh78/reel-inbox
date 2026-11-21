import Foundation

enum SettingsKey {
    static let openMode = "settings.openMode"
    static let markWatchedOnOpen = "settings.markWatchedOnOpen"
    static let returnToInbox = "settings.returnToInbox"
    static let loadPreviews = "settings.loadPreviews"
}

/// Where the Watch button opens a reel.
enum OpenMode: String, CaseIterable, Identifiable {
    case instagramApp
    case focusedPlayer
    case inAppBrowser

    var id: String { rawValue }

    var title: String {
        switch self {
        case .instagramApp: return "Instagram app"
        case .focusedPlayer: return "Focused player"
        case .inAppBrowser: return "In-app browser"
        }
    }

    var explanation: String {
        switch self {
        case .instagramApp:
            return "Opens the reel in the official Instagram app. Most reliable, but Instagram's own viewer can still let you swipe to more reels. This app cannot change that."
        case .focusedPlayer:
            return "Shows only this reel, using Instagram's official embed, inside Reel Inbox. There is no feed and no next reel. Embeds only work for public accounts that allow embedding, so some reels will not play here. Use the Open in Instagram button for those."
        case .inAppBrowser:
            return "Opens instagram.com in a Safari view inside this app. Instagram may ask you to log in, and its website may show other content."
        }
    }
}

/// Read-only snapshot of the user's settings. Defaults must match the
/// `@AppStorage` defaults used in the views.
struct AppSettings {
    var openMode: OpenMode
    var markWatchedOnOpen: Bool
    var returnToInbox: Bool
    var loadPreviews: Bool

    static var current: AppSettings {
        let defaults = UserDefaults.standard
        return AppSettings(
            openMode: defaults.string(forKey: SettingsKey.openMode).flatMap(OpenMode.init(rawValue:)) ?? .instagramApp,
            markWatchedOnOpen: defaults.object(forKey: SettingsKey.markWatchedOnOpen) as? Bool ?? true,
            returnToInbox: defaults.object(forKey: SettingsKey.returnToInbox) as? Bool ?? true,
            loadPreviews: defaults.object(forKey: SettingsKey.loadPreviews) as? Bool ?? false
        )
    }
}
