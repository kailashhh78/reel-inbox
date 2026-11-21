import UIKit
import UniformTypeIdentifiers

/// Fallback handoff for when no App Group is available (for example, after a
/// re-signing tool dropped the App Group entitlement).
///
/// The Share Extension puts the shared link on the system clipboard together
/// with a private marker item. When Reel Inbox becomes active it checks for the
/// marker. Checking item *types* doesn't trigger iOS's paste prompt; reading the
/// data does, so iOS may ask "Allow Paste" unless you set
/// Settings > Apps > Reel Inbox > Paste from Other Apps > Allow.
///
/// Limitation: if you copy something else before opening Reel Inbox, the
/// handoff is replaced and lost (share the reel again).
enum PasteboardHandoff {
    /// Private pasteboard type that marks our handoff item.
    static let markerType = "com.reelinbox.pending-share.v1"

    static func write(_ share: PendingShare) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(share)
        let item: [String: Any] = [
            markerType: data,
            UTType.plainText.identifier: share.urlString,
        ]
        UIPasteboard.general.setItems(
            [item],
            options: [.expirationDate: Date().addingTimeInterval(24 * 60 * 60)]
        )
    }

    /// Cheap check that does not read clipboard contents.
    static var hasPendingShare: Bool {
        UIPasteboard.general.contains(pasteboardTypes: [markerType])
    }

    /// Reads and consumes the handoff. Leaves the plain link on the clipboard.
    static func take() -> PendingShare? {
        guard hasPendingShare,
              let data = UIPasteboard.general.data(forPasteboardType: markerType)
        else { return nil }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let share = try? decoder.decode(PendingShare.self, from: data) else { return nil }

        // Remove our marker so the same share isn't imported twice.
        UIPasteboard.general.string = share.urlString
        return share
    }
}
