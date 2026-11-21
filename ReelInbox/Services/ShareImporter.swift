import Foundation
import SwiftData

struct ImportSummary {
    var added = 0
    var merged = 0
    var discarded = 0
}

/// Moves links queued by the Share Extension into the SwiftData store.
@MainActor
enum ShareImporter {
    static func importPending(into context: ModelContext) throws -> ImportSummary {
        var summary = ImportSummary()

        for entry in try PendingShareStore.pendingEntries() {
            guard let share = entry.share,
                  let link = InstagramLink.firstLink(in: share.urlString)
            else {
                // Unreadable or not an Instagram link: drop it so it isn't retried forever.
                PendingShareStore.remove(entry.fileURL)
                summary.discarded += 1
                continue
            }

            do {
                let outcome = try ReelRepository.upsert(
                    link: link,
                    sender: share.sender,
                    note: share.note,
                    date: share.sharedAt,
                    in: context
                )
                try context.save()
                // Only remove the queued file once the reel is safely persisted.
                PendingShareStore.remove(entry.fileURL)
                switch outcome {
                case .inserted: summary.added += 1
                case .alreadyExisted: summary.merged += 1
                }
            } catch {
                context.rollback()
                throw error
            }
        }
        return summary
    }
}
