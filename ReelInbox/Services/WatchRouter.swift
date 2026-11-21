import SwiftData
import SwiftUI
import UIKit

struct SafariItem: Identifiable {
    let id = UUID()
    let url: URL
}

/// A reel or post tapped inside Messages, shown in the locked single-reel viewer.
struct MediaPresentation: Identifiable {
    let id = UUID()
    let link: InstagramLink
}

/// Decides how the Watch button opens a reel, and holds app-wide presentation state.
@MainActor
@Observable
final class WatchRouter {
    var playerReel: Reel?
    var safariItem: SafariItem?
    var messagesMedia: MediaPresentation?
    var alertMessage: String?
    /// Last error from importing Share Extension links (shown as a banner in the Inbox).
    var importErrorMessage: String?

    func watch(_ reel: Reel, in context: ModelContext) {
        guard let url = reel.url else {
            alertMessage = "This saved link is not a valid URL."
            return
        }

        let settings = AppSettings.current

        if settings.markWatchedOnOpen && !reel.isWatched {
            reel.setWatched(true)
            save(context)
        }

        switch settings.openMode {
        case .instagramApp:
            openInInstagram(url)
        case .focusedPlayer:
            if reel.link?.supportsEmbed == true {
                playerReel = reel
            } else {
                // /share/ links have no shortcode, so they cannot be embedded.
                openInInstagram(url)
            }
        case .inAppBrowser:
            safariItem = SafariItem(url: url)
        }
    }

    /// Opens an https://www.instagram.com/... link in the Instagram app through its
    /// universal link. `.universalLinksOnly` makes iOS report failure instead of
    /// opening Safari when the Instagram app isn't installed (or the user turned
    /// universal links off for instagram.com). Then the link opens in the in-app browser.
    func openInInstagram(_ url: URL) {
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { [weak self] success in
            guard !success else { return }
            Task { @MainActor in
                self?.safariItem = SafariItem(url: url)
            }
        }
    }

    func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            alertMessage = "Couldn't save changes: \(error.localizedDescription)"
        }
    }

    func runImport(_ context: ModelContext) {
        importErrorMessage = ShareImporter.importAll(into: context)
    }
}
