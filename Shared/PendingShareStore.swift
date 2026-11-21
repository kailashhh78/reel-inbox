import Foundation

/// One link handed over by the Share Extension, waiting to be imported by the app.
struct PendingShare: Codable, Identifiable, Equatable {
    var id: UUID
    var urlString: String
    var sender: String
    var note: String
    var sharedAt: Date
}

enum PendingShareStoreError: LocalizedError {
    case appGroupUnavailable

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "The shared App Group container is unavailable. In Xcode, make sure both the ReelInbox and ShareExtension targets list the App Group \"\(AppGroup.identifier)\" under Signing & Capabilities."
        }
    }
}

/// A tiny file-based queue inside the App Group container.
///
/// The Share Extension writes one JSON file per shared link. The main app reads
/// the files, inserts them into its SwiftData store, then deletes them.
/// Using files (instead of opening the SwiftData store from two processes)
/// keeps the extension small and avoids cross-process database contention.
enum PendingShareStore {
    private static let folderName = "PendingShares"
    private static let fileExtension = "json"

    struct Entry {
        let fileURL: URL
        /// `nil` when the file could not be decoded (it will be discarded).
        let share: PendingShare?
    }

    static func directoryURL() throws -> URL {
        guard let container = AppGroup.containerURL else {
            throw PendingShareStoreError.appGroupUnavailable
        }
        let directory = container.appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    static func enqueue(_ share: PendingShare) throws {
        let directory = try directoryURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(share)
        let fileURL = directory.appendingPathComponent("\(share.id.uuidString).\(fileExtension)")
        try data.write(to: fileURL, options: [.atomic])
    }

    /// All queued shares, oldest first.
    static func pendingEntries() throws -> [Entry] {
        let directory = try directoryURL()
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == fileExtension }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let entries = files.map { url -> Entry in
            let share = (try? Data(contentsOf: url)).flatMap { try? decoder.decode(PendingShare.self, from: $0) }
            return Entry(fileURL: url, share: share)
        }
        return entries.sorted { lhs, rhs in
            (lhs.share?.sharedAt ?? .distantPast) < (rhs.share?.sharedAt ?? .distantPast)
        }
    }

    static func pendingCount() -> Int {
        (try? pendingEntries().count) ?? 0
    }

    static func remove(_ fileURL: URL) {
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func removeAll() throws {
        for entry in try pendingEntries() {
            remove(entry.fileURL)
        }
    }
}
