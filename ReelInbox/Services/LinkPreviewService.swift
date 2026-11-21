import LinkPresentation
import SwiftData
import UIKit

/// Optional link previews through Apple's LinkPresentation framework (the same
/// mechanism Messages uses). Only runs when "Show link previews" is on.
/// It reads the public page metadata (title and image) and nothing else.
/// No login, no private content.
@MainActor
enum LinkPreviewService {
    private static var inFlight: Set<String> = []

    static func fetchPreviewIfNeeded(for reel: Reel, context: ModelContext) async {
        guard reel.previewFetchedAt == nil,
              let url = reel.url,
              !inFlight.contains(reel.canonicalURL)
        else { return }

        let key = reel.canonicalURL
        inFlight.insert(key)
        defer { inFlight.remove(key) }

        let provider = LPMetadataProvider()
        provider.timeout = 15

        var title: String?
        var thumbnail: Data?
        do {
            let metadata = try await provider.startFetchingMetadata(for: url)
            title = metadata.title
            if let imageProvider = metadata.imageProvider,
               let image = await loadImage(from: imageProvider) {
                thumbnail = makeThumbnail(from: image)
            }
        } catch {
            // Network failure, login wall, or timeout. Mark it as attempted so we don't retry on every scroll.
        }

        // The reel may have been deleted while we were waiting.
        guard reel.modelContext != nil, !reel.isDeleted else { return }
        reel.previewTitle = title
        reel.thumbnailData = thumbnail
        reel.previewFetchedAt = .now
        try? context.save()
    }

    private static func loadImage(from provider: NSItemProvider) async -> UIImage? {
        guard provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    private static func makeThumbnail(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 300
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxSide / max(size.width, size.height))
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())
        let thumbnail = image.preparingThumbnail(of: target) ?? image
        return thumbnail.jpegData(compressionQuality: 0.8)
    }
}
