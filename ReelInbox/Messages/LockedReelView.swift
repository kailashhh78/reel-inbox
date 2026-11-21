import SwiftUI
import WebKit

/// Shows exactly one reel or post from a DM, logged in, on Instagram's own page.
/// Moving to any other reel, profile or page is blocked. Swiping to "next" just
/// snaps back. Tap Done to return to the chat.
struct LockedReelView: View {
    @Environment(\.dismiss) private var dismiss
    let link: InstagramLink
    @State private var loadState: EmbedWebView.LoadState = .loading

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if link.shortcode != nil {
                    LockedReelWebView(link: link, state: $loadState)
                }

                switch loadState {
                case .loading:
                    ProgressView()
                case .loaded:
                    EmptyView()
                case .failed(let message):
                    ContentUnavailableView {
                        Label("Couldn't load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Close") { dismiss() }
                            .buttonStyle(.bordered)
                    }
                    .background(Theme.background)
                }
            }
            .navigationTitle(link.kind.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct LockedReelWebView: UIViewRepresentable {
    let link: InstagramLink
    @Binding var state: EmbedWebView.LoadState

    func makeCoordinator() -> Coordinator {
        Coordinator(link: link, state: $state)
    }

    func makeUIView(context: Context) -> WKWebView {
        let script = InstagramWeb.guardScript(
            allowedPathPattern: Coordinator.allowedPathPattern(for: link),
            fallbackURL: link.canonicalURL,
            interceptMedia: false,
            css: InstagramWeb.hideDistractionsCSS
        )
        let configuration = InstagramWeb.makeConfiguration(script: script, messageHandler: nil)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        webView.load(URLRequest(url: link.canonicalURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let link: InstagramLink
        private var state: Binding<EmbedWebView.LoadState>

        init(link: InstagramLink, state: Binding<EmbedWebView.LoadState>) {
            self.link = link
            self.state = state
        }

        /// This one reel (in any URL form) plus login pages.
        static func allowedPathPattern(for link: InstagramLink) -> String {
            let code = link.shortcode ?? "-"
            return "^/(?:[A-Za-z0-9._]+/)?(?:reel|reels|p|tv)/\(code)/?$|^/(accounts|challenge|two_factor|auth_platform)(/|$)"
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let scheme = url.scheme?.lowercased() ?? ""
            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

            if !isMainFrame {
                decisionHandler(["http", "https", "about", "blob", "data"].contains(scheme) ? .allow : .cancel)
                return
            }
            if ["about", "blob", "data"].contains(scheme) {
                decisionHandler(.allow)
                return
            }
            guard scheme == "https" || scheme == "http" else {
                decisionHandler(.cancel)
                return
            }

            let host = url.host?.lowercased() ?? ""
            if InstagramWeb.loginHelperHosts.contains(host) {
                decisionHandler(.allow)
                return
            }
            if InstagramWeb.instagramHosts.contains(host) {
                if let target = InstagramLink.parse(url), target.shortcode == link.shortcode {
                    decisionHandler(.allow)
                    return
                }
                if url.path.range(of: "^/(accounts|challenge|two_factor|auth_platform)(/|$)", options: .regularExpression) != nil {
                    decisionHandler(.allow)
                    return
                }
            }
            decisionHandler(.cancel)
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            state.wrappedValue = .loaded
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            report(error)
        }

        private func report(_ error: Error) {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
            if nsError.domain == "WebKitErrorDomain" && nsError.code == 102 { return }
            state.wrappedValue = .failed(error.localizedDescription)
        }
    }
}
