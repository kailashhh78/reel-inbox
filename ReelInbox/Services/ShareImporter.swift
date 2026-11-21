import Foundation
import SwiftData

/// Moves links handed over by the Share Extension into the SwiftData store.
/// Two transports:
///   1. App Group files (`PendingShareStore`), used normally.
///   2. Clipboard (`PasteboardHandoff`), used when no App Group is available.
@MainActor
enum ShareImporter {
    /// Imports everything waiting. Returns a user-facing error message, or nil on success.
    static func importAll(into context: ModelContext) -> String? {
        var errorMessage: String?

        if AppGroup.containerURL != nil {
            do {
                try importAppGroupQueue(into: context)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        if let share = PasteboardHandoff.take() {
            do {
                try importShare(share, into: context)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        return errorMessage
    }

    private static func importAppGroupQueue(into context: ModelContext) throws {
        for entry in try PendingShareStore.pendingEntries() {
            guard let share = entry.share else {
                // Unreadable file: drop it so it isn't retried forever.
                PendingShareStore.remove(entry.fileURL)
                continue
            }
            try importShare(share, into: context)
            // Only remove the queued file once the reel is safely persisted.
            PendingShareStore.remove(entry.fileURL)
        }
    }

    /// Inserts (or merges) one share and saves. Silently ignores non-Instagram links.
    static func importShare(_ share: PendingShare, into context: ModelContext) throws {
        guard let link = InstagramLink.firstLink(in: share.urlString) else { return }
        do {
            try ReelRepository.upsert(
                link: link,
                sender: share.sender,
                note: share.note,
                date: share.sharedAt,
                in: context
            )
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
