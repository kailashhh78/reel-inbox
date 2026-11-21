import Foundation
import UniformTypeIdentifiers

@MainActor
final class ShareViewModel: ObservableObject {
    enum Phase: Equatable {
        case loading
        case ready(InstagramLink)
        case invalid
        /// `viaClipboard`: no App Group was available, so the link went through the clipboard.
        case saved(viaClipboard: Bool)
        case failed(String)
    }

    @Published var phase: Phase = .loading
    @Published var sender = ""
    @Published var note = ""

    private let extensionContext: NSExtensionContext?

    init(extensionContext: NSExtensionContext?) {
        self.extensionContext = extensionContext
    }

    var canSave: Bool {
        if case .ready = phase { return true }
        return false
    }

    func load() {
        let items = extensionContext?.inputItems ?? []
        Task {
            let candidates = await ShareInputExtractor.candidateStrings(from: items)
            if let link = candidates.lazy.compactMap({ InstagramLink.firstLink(in: $0) }).first {
                phase = .ready(link)
            } else {
                phase = .invalid
            }
        }
    }

    func save() {
        guard case .ready(let link) = phase else { return }
        let share = PendingShare(
            id: UUID(),
            urlString: link.canonicalURL.absoluteString,
            sender: sender.trimmingCharacters(in: .whitespacesAndNewlines),
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            sharedAt: Date()
        )
        do {
            let viaClipboard: Bool
            if AppGroup.containerURL != nil {
                try PendingShareStore.enqueue(share)
                viaClipboard = false
            } else {
                try PasteboardHandoff.write(share)
                viaClipboard = true
            }
            phase = .saved(viaClipboard: viaClipboard)
            // Brief confirmation, then close the sheet and return to Instagram.
            let delay: UInt64 = viaClipboard ? 2_500_000_000 : 700_000_000
            Task {
                try? await Task.sleep(nanoseconds: delay)
                complete()
            }
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func complete() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    func cancel() {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        extensionContext?.cancelRequest(withError: error)
    }
}

/// Pulls every URL or text string out of the share sheet's input.
/// Apps differ: some share a URL item, some plain text that contains a URL.
enum ShareInputExtractor {
    static func candidateStrings(from inputItems: [Any]) async -> [String] {
        var results: [String] = []
        for case let item as NSExtensionItem in inputItems {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let value = await loadString(from: provider, typeIdentifier: UTType.url.identifier) {
                    results.append(value)
                }
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                   let value = await loadString(from: provider, typeIdentifier: UTType.plainText.identifier) {
                    results.append(value)
                }
            }
            if let text = item.attributedContentText?.string, !text.isEmpty {
                results.append(text)
            }
        }
        return results
    }

    private static func loadString(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                let value: String?
                switch item {
                case let url as URL:
                    value = url.absoluteString
                case let string as String:
                    value = string
                case let attributed as NSAttributedString:
                    value = attributed.string
                case let data as Data:
                    value = String(data: data, encoding: .utf8)
                        ?? URL(dataRepresentation: data, relativeTo: nil)?.absoluteString
                default:
                    value = nil
                }
                continuation.resume(returning: value)
            }
        }
    }
}
