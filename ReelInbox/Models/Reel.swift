import Foundation
import SwiftData

/// A link a friend sent you. Stored only on this device.
@Model
final class Reel {
    /// Normalized link (no tracking parameters). Used to avoid duplicates.
    @Attribute(.unique) var canonicalURL: String
    var shortcode: String?
    var kindRaw: String
    /// Entered manually; may be empty.
    var sender: String
    var note: String
    var dateReceived: Date
    var isWatched: Bool
    var watchedAt: Date?
    var isSaved: Bool

    // Optional link preview (only fetched when enabled in Settings).
    @Attribute(.externalStorage) var thumbnailData: Data?
    var previewTitle: String?
    var previewFetchedAt: Date?

    init(link: InstagramLink, sender: String = "", note: String = "", dateReceived: Date = .now) {
        self.canonicalURL = link.canonicalURL.absoluteString
        self.shortcode = link.shortcode
        self.kindRaw = link.kind.rawValue
        self.sender = sender
        self.note = note
        self.dateReceived = dateReceived
        self.isWatched = false
        self.watchedAt = nil
        self.isSaved = false
        self.thumbnailData = nil
        self.previewTitle = nil
        self.previewFetchedAt = nil
    }

    var kind: InstagramLink.Kind {
        InstagramLink.Kind(rawValue: kindRaw) ?? .reel
    }

    var url: URL? {
        URL(string: canonicalURL)
    }

    var link: InstagramLink? {
        url.flatMap { InstagramLink.parse($0) }
    }

    var displayLink: String {
        canonicalURL.replacingOccurrences(of: "https://www.", with: "")
    }

    func setWatched(_ watched: Bool) {
        isWatched = watched
        watchedAt = watched ? .now : nil
    }
}
