import Foundation
import SwiftData

enum UpsertOutcome {
    case inserted
    case alreadyExisted
}

/// All writes to the SwiftData store go through here.
@MainActor
enum ReelRepository {
    /// Inserts a new reel, or merges sender/note into an existing one with the same link.
    /// Does not call `save()`; callers decide when to persist.
    @discardableResult
    static func upsert(
        link: InstagramLink,
        sender: String,
        note: String,
        date: Date,
        in context: ModelContext
    ) throws -> UpsertOutcome {
        let key = link.canonicalURL.absoluteString
        var descriptor = FetchDescriptor<Reel>(predicate: #Predicate<Reel> { $0.canonicalURL == key })
        descriptor.fetchLimit = 1

        let cleanSender = sender.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanNote = note.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = try context.fetch(descriptor).first {
            if !cleanSender.isEmpty {
                if existing.sender.isEmpty {
                    existing.sender = cleanSender
                } else if !existing.sender.localizedCaseInsensitiveContains(cleanSender) {
                    existing.sender += ", \(cleanSender)"
                }
            }
            if !cleanNote.isEmpty && existing.note.isEmpty {
                existing.note = cleanNote
            }
            return .alreadyExisted
        }

        context.insert(Reel(link: link, sender: cleanSender, note: cleanNote, dateReceived: date))
        return .inserted
    }

    /// Records a reel opened from Messages in the Watched history.
    static func recordWatchedFromMessages(_ link: InstagramLink, in context: ModelContext) throws {
        try upsert(link: link, sender: "", note: "", date: .now, in: context)
        let key = link.canonicalURL.absoluteString
        var descriptor = FetchDescriptor<Reel>(predicate: #Predicate<Reel> { $0.canonicalURL == key })
        descriptor.fetchLimit = 1
        if let reel = try context.fetch(descriptor).first, !reel.isWatched {
            reel.setWatched(true)
        }
        try context.save()
    }

    static func delete(_ reel: Reel, in context: ModelContext) throws {
        context.delete(reel)
        try context.save()
    }

    /// Deletes every reel matching `predicate`. Returns how many were deleted.
    @discardableResult
    static func deleteAll(matching predicate: Predicate<Reel>?, in context: ModelContext) throws -> Int {
        let reels = try context.fetch(FetchDescriptor<Reel>(predicate: predicate))
        for reel in reels {
            context.delete(reel)
        }
        try context.save()
        return reels.count
    }

    static func count(matching predicate: Predicate<Reel>?, in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<Reel>(predicate: predicate))) ?? 0
    }

    // Predicates shared by the screens.
    static let unwatchedUnsaved = #Predicate<Reel> { $0.isWatched == false && $0.isSaved == false }
    static let watchedUnsaved = #Predicate<Reel> { $0.isWatched == true && $0.isSaved == false }
}
