import SwiftUI

/// Plays exactly one reel through Instagram's official embed. There is no feed,
/// no autoplay, no "next" reel, and links inside the embed can't take you away.
struct FocusedPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(WatchRouter.self) private var router

    let reel: Reel
    @State private var loadState: EmbedWebView.LoadState = .loading

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if let link = reel.link, let html = InstagramEmbed.html(for: link) {
                    EmbedWebView(html: html, baseURL: InstagramEmbed.baseURL, state: $loadState)
                        .ignoresSafeArea(edges: .bottom)

                    switch loadState {
                    case .loading:
                        ProgressView()
                    case .loaded:
                        EmptyView()
                    case .failed(let message):
                        failure(message)
                    }
                } else {
                    failure("This kind of link can't be shown in the focused player.")
                }
            }
            .navigationTitle(reel.sender.isEmpty ? reel.kind.displayName : "From \(reel.sender)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        openInInstagram()
                    } label: {
                        Label("Open in Instagram", systemImage: "arrow.up.right.square")
                    }
                }
            }
        }
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("Can't play here", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Open in Instagram") { openInInstagram() }
                .buttonStyle(.borderedProminent)
        }
        .background(Theme.background)
    }

    private func openInInstagram() {
        guard let url = reel.url else { return }
        dismiss()
        router.openInInstagram(url)
    }
}

/// Builds the official embed markup described in Meta's docs: a
/// `blockquote.instagram-media` with the post permalink, plus
/// https://www.instagram.com/embed.js, which turns it into the rendered post.
/// Works only for public posts on accounts that allow embedding.
enum InstagramEmbed {
    /// Placeholder origin for the local HTML document. `.invalid` is reserved
    /// (RFC 2606), so it can never resolve to a real site.
    static let baseURL = URL(string: "https://reelinbox.invalid/")!

    static func html(for link: InstagramLink) -> String? {
        guard link.supportsEmbed else { return nil }
        let permalink = escapeAttribute(link.canonicalURL.absoluteString)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>
          html, body { margin: 0; padding: 0; background: transparent; }
          body { padding: 12px; display: flex; justify-content: center; }
          .instagram-media { margin: 0 auto !important; min-width: 0 !important; width: 100% !important; }
        </style>
        </head>
        <body>
        <blockquote class="instagram-media" data-instgrm-permalink="\(permalink)" data-instgrm-version="14" style="background:#FFF; border:0; border-radius:12px; margin:0; max-width:658px; padding:0; width:100%;">
          <a href="\(permalink)">View this on Instagram</a>
        </blockquote>
        <script async src="https://www.instagram.com/embed.js"></script>
        </body>
        </html>
        """
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
